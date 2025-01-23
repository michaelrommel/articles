---
thumbnailUrl: "/articles/assets/2025-01-23-neovim-lsp-pull-diagnostics/thumbnail.png"
thumbnailTitle: "Icon showing wrong lsp errors"
structuredData: {
    "@context": "https://schema.org",
    "@type": "Article",
    author: {
        "@type": "Person",
        "name": "Michael Rommel",
        "url": "https://michaelrommel.com/info/about",
        "image": "https://avatars.githubusercontent.com/u/919935?s=100&v=4"
    },
    "dateModified": "2025-01-23T13:13:04+01:00",
    "datePublished": "2025-01-23T00:00:00+01:00",
    "headline": "JSON5 Linting In Neovim",
    "abstract": "How to supporess false diagnostics errors for JSON5 files with neovim's language servers."
}
tags: ["new", "create", "code", "neovim", "lsp", "diagnostics"]
published: true
---

# JSON5 Linting In Neovim

## Motivation

In neovim 0.9.5 I had a configuration that allowed me to suppress false error messages
in JSON5 files. The language server, that was extracted fro VScode does not understand
JSON5 files and flags comments or trailing commas as errors.

![Screenshot of neovim](/articles/assets/2025-01-23-neovim-lsp-pull-diagnostics/thumbnail.png)

When I upgraded to version 0.10.3 this configuration stopped working and I needed a fix
for that. 

## Initial Setup

I am using `mason-lspconfig` to install and setup language servers in neovim. In the setup
of the language servers, you can override the handlers for specific LSP methods, like
`textdocument/publishDiagnostics`, do some modifications to the diagnostic results and
suppress the false positives, then call the corresponding on_xxx default handler.

My config looked like this:

```lua
require("mason-lspconfig").setup_handlers {
    -- The first entry (without a key) will be the default handler
    function(server_name)
        -- print("server_name is " .. server_name)
        require("lspconfig")[server_name].setup({
            on_attach = on_attach,
            capabilities = capabilities,
        })
    end,
    -- Next, you can provide a dedicated handler for specific servers.
    ["jsonls"] = function()
        print("installing jsonls handler")
        vim.lsp.set_log_level("debug")
        -- a reference to the default handler
        local on_diagnostic = vim.lsp.handlers["textDocument/diagnostic"]
        require("lspconfig").jsonls.setup({
            on_attach = on_attach,
            capabilities = capabilities,
            filetypes = { "json", "jsonc", "json5" },
            init_options = {
                provideFormatter = false,
            },
            handlers = {
                -- this is the push handling of diagnostics information
                ["textDocument/publishDiagnostics"] = function(err, result, ctx, config) -- [!code highlight]
                    -- jsonls doesn't really support json5
                    -- remove some annoying errors
                    if string.match(result.uri, "%.json5$", -6) 
                        and result.diagnostics ~= nil then
                        local idx = 1
                        while idx <= #result.diagnostics do
                            if result.diagnostics[idx].code == 519 then
                                print("suppressing: " .. result.diagnostics[idx].code)
                                -- "Trailing comma""
                                table.remove(result.diagnostics, idx)
                            elseif result.diagnostics[idx].code == 521 then
                                print("suppressing: " .. result.diagnostics[idx].code)
                                -- "Comments are not permitted in JSON."
                                table.remove(result.diagnostics, idx)
                            else
                                idx = idx + 1
                            end
                        end
                    end
                    vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
                end,
            },
        })
    end,
end,

```

In the first lines I set up a generic handler for all language servers. There I set
commonly used functionality, e.g. I set up the keymaps for code actions, hover etc. there.
Following that I configure specific settings for each language server, that needs
tweaking.

In this case for the JSON language server I register a handler, that removes the errors
from the diagnostics reports that are sent by the server as part of the method
`[textDocument/publishDiagnostics]` for JSON5 files only.


## Observed Behaviour

Once I started using neovim 0.10.x I suddenly the errors in the JSON5 documents came back
to haunt me again. Initially I was unsure, whether it was a change in:

- neovim
- mason-lspconfig
- nvim-lspconfig
- jsonls

that were causing the problems. So I started with a few `print()` statements in the
custome handlers and soon found out, that in jsonls my handler was no longer called, 
but for python the handler **was** indeed called.

After hours and hours of searching and installing different versions of plugins, language
server and neovim, I tracked it down to neovim being the culprit. The same config with the
same plugin versions and the same language server exhibited different behaviour.


## The Culprit

Several hours later I could pin it down to different messages being exchanged between LSP
client in neovim and the LSP Server.

In 0.9.5 the client sent only a `textDocument/didChange` message and the server itself
produced a `textDocument/publishDiagnostics` response, containing the found issues with
the code.

From 0.10.0 onwards, the client still sent the `textDocument/didChange` message, but also
sent an `textDocument/diagnostic` message, that triggers the LSP server to evaluate and
send the response back. This time, the response message does not carry any method at all
and has a different structure from `provideDiagnostics`.

This begged the question, why the different behaviours could not be observed with the
`jedi-language-server`? The answer lies in the negotiation of the server's capabilities.
When asked by the LSP client, the `jsonls` answers with both capabilities, whereas `jedi`
does not provide the diagnostics capabilities at all in the response. So when nvim 0.10
detects the `textDocument/diagnostic` capability, it will use this in favour over the
older `publishDiagnostics` capability. Apparently the benefits for the editor is, that it
can ask specifically for updates on a particular file:

> Diagnostics are currently published by the server to the client using a notification.
> This model has the advantage that for workspace wide diagnostics the server has the
> freedom to compute them at a server preferred point in time. On the other hand the
> approach has the disadvantage that the server can’t prioritize the computation for the
> file in which the user types or which are visible in the editor. Inferring the client’s
> UI state from the textDocument/didOpen and textDocument/didChange notifications might
> lead to false positives since these notifications are ownership transfer notifications.
>
> The specification therefore introduces the concept of diagnostic pull requests to give a
> client more control over the documents for which diagnostics should be computed and at
> which point in time.

Reference: [Microsoft LSP Spec](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_pullDiagnostics)

The implementation of `textDocument/diagnostic` in neovim is buried in the 0.10.0 
commit message under the "Feature" heading, not the "Breaking" heading.


## How To Fix It

So now I knew I had to somehow patch into the rpc response that was sent by the language
server. But I had no clue, where to start, since the message was missing the method. So
which handler to override? My first gut feeling was to override the corresponding
`textDocument/diagnostic` handler.

Using the same code fragment with just the method name changed, did not work. Then I
started to read neovim's source code for the LSP portion. The lsp.log file told me the
line number in `runtime/lua/vim/lsp/client.lua` where the rpc message is sent to the
server. There it was clear, that the handler is given as a callback, so overriding the
above mentioned hander was indeed the right choice.

I had then to just change a different table: instead of `result.diagnostics` I needed to
modify `result.items`. Then a little bit different method of checking, whether the file is
a `json` or `json5` file, because the uri was not part of the response. I refactored the
common part out into its own private function.

The result can be found [here](https://github.com/michaelrommel/castle-neovim/blob/dbbac16/dirs/.config/miro/lua/plugins/mason-lspconfig.lua#L81)

## Conclusion

In the end it was a very small fix/change. Looking at this 20 line change, everyone would
wonder, why this took several hours to complete. The benefits of all that time consuming
debugging is really a better understanding of the inner workings of one of my favourite
tools in computing. I spend so much time in this editor, that I really like to dive deep
here.

On the other hand, I found that:

- the documentation of the lsp only covers the basics of the "old" model of push
  diagnostics messages and give no examples of how to deal with more modern language
  servers.
- the discussion sections of github are not a great place to get help. If you have a very
  successful project like neovim, there are tons of discussions going on and apparently
  the average level of knowledge of people hanging out there is not enough to tackle
  deeper problems. And the core devs are more looking into issues and not discussions,
  which I completely agree with. I deliberately did not open a bug, just for lack of
  documentation.
- the benefits of having a project build upon open source is invaluable. It empowers me
  every time to figure out solutions on my own and not have to wait for others.

  If you have any thoughts on this article, please share it [here](https://github.com/michaelrommel/articles/discussions/2)

