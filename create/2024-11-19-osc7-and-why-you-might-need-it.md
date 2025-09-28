---
thumbnailUrl: "/articles/assets/2024-11-19-osc7-and-why-you-might-need-it/thumbnail.png"
thumbnailTitle: "Icon showing a terminal with split panes"
structuredData: {
    "@context": "https://schema.org",
    "@type": "Article",
    author: { 
        "@type": "Person", 
        "name": "Michael Rommel",
        "url": "https://michaelrommel.com/info/about",
        "image": "https://avatars.githubusercontent.com/u/919935?s=100&v=4"
    },
    "dateModified": "2025-09-28T22:43:51+02:00",
    "datePublished": "2024-11-19T18:13:02+01:00",
    "headline": "OSC7 And Why You Might Need It",
    "abstract": "A short description of why and how you can use OSC7 to make your terminal life easier."
}
tags: ["new", "create", "code"]
published: true
---

# OSC7 And Why You Might Need It

## Motivation

You may have found yourself in the situation where you started `tmux` and are
working in the terminal. You switch to your code in a directory and then
you divide the screen up into more panes, e.g. to have a pane with the
editor, another where you start the application and a third one to `tail -f`
the logs.

After you have split the screen, the new pane's `cwd` is usually the
directory where you had been in when you started `tmux`. You would then
need to switch again to your code directory and do the same again in your third
pane.

This is where `OSC7` comes in.

## What is OSC7?

`OSC7` is a terminal escape sequence that advises a terminal of the working
directory. So in order to take advantage of that all three components:
Shell, Terminal Multiplexer and Terminal need to work together. OSC stands
for Operating System Command.

## Configuration

The shell has the task to emit the `OSC7` sequence whenever the directory 
changes.

Some terminal prompt managers like `oh-my-posh` already have an integration
so you can just use that top level configuration:

`.oh-my-posh/posh.json`:

```js
{
	"$schema": "https://raw.githubu...chema.json",
	"version": 2,
	"pwd": "osc7",
    ...
}
```

If your prompt manager does not support this, e.g. starship in version 1.23.0,
you have to configure the shell itself. Modern shells offer the capability to
execute arbitrary commands, when the prompt is displayed.

`zsh`:

```shell
# emit current working directory using osc 7 terminal escape code
# https://iterm2.com/documentation-escape-codes.html
# https://github.com/wez/wezterm/discussions/3718
# https://wezfurlong.org/wezterm/config/lua/config/default_cwd.html
# https://github.com/wez/wezterm/discussions/4945
_urlencode() {
        local length="${#1}"
        for (( i = 0; i < length; i++ )); do
                local c="${1:$i:1}"
                case $c in
                        %) printf '%%%02X' "'$c" ;;
                        *) printf "%s" "$c" ;;
                esac
        done
}
_set_cwd_osc7() {
        EP="$(_urlencode "$PWD")"
        echo -ne "\033]7;file://$HOSTNAME/$EP\033\\"
}
precmd_functions+=(_set_cwd_osc7)
```

or `bash`:

```shell
_osc7() {
        printf "\033]7;file://%s%s\033\\" "${HOSTNAME}" "${PWD}"
}
PROMPT_COMMAND="_osc7${PROMPT_COMMAND:+$'\n'$PROMPT_COMMAND}"
```

Note that the bash variant lacks the proper encoding stuff and is minimalistic,
just an example. I do not use bash anymore for interactive shells, so this
extension is left as an exercise to the reader. Also, if using bash version 5.3
or higher the PROMPT_COMMAND also supports arrays instead of one newline delimited
large command.

Now that the shell in one way or another informs the terminal about the current
working directory we need to configure two things to make that work with terminal
multiplexers like `tmux`:

1. `tmux` should pass on this information, so that the outer terminal also receives it
1. and we can actually make use of this information inside tmux

These are the `tmux` tweaks:

`.config/tmux/tmux.conf`:

```tmux
# split using the OSC7 path, this has the format:
# file://hostname//home/rommel/software/rust
# note that the colon cannot be matched directly
bind-key '"'   split-window -h -c '#{s|file.//.*//|/|:pane_path}'
bind-key %     split-window -c '#{s|file.//.*//|/|:pane_path}'
bind-key c     new-window -c '#{s|file.//.*//|/|:pane_path}'

if-shell -b '[ "$(echo "$TMUX_VERSION >= 3.4" | bc)" = 1 ]' {
  # allow special OSC control escapes to pass through
  # used to send macos desktop notifications from scripts
  # although a pane option, it can be set on a global window level
  set -wg allow-passthrough on
}
```

New splits or new windows will automatically get the current working directory
set to the `OSC7` defined path of the pane we split from (instead of being
dropped in the directory, where `tmux` was started).

![tmux shell split](/articles/assets/2024-11-19-osc7-and-why-you-might-need-it/thumbnail.png)

And since `wezterm` also now receives this information any new `wezterm` tab created
with `Ctrl-Shift-t` drops the shell into that remembered directory.

## Conclusion

With very little effort working in the terminal has been much more
streamlined for me compared to before. Many of the tedious `cd .....`
commands that I used to type (even with tab completion) are now a thing of
the past.

