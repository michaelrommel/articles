---
thumbnailUrl: "/articles/assets/2025-09-28-wezterm-tab-info/thumbnail.png"
thumbnailTitle: "Icon showing a terminal with coloured tabs"
structuredData: {
    "@context": "https://schema.org",
    "@type": "Article",
    author: { 
        "@type": "Person", 
        "name": "Michael Rommel",
        "url": "https://michaelrommel.com/info/about",
        "image": "https://avatars.githubusercontent.com/u/919935?s=100&v=4"
    },
    "dateModified": "2025-09-28T22:54:05+02:00",
    "datePublished": "2025-09-28T22:54:07+02:00",
    "headline": "Wezterm's Tabs (Colours / Icons)",
    "abstract": "Describing how you can convey helpful information in your Wezterm tabs."
}
tags: ["new", "create", "code", "wezterm", "OSC7", "OSC1337"]
published: true
---

# Wezterm's Tabs (Colours / Icons)

## Motivation

While reworking my OSC7 configuration, that stopped when I switched to starship as 
prompt manager, I stumbled over an issue in Wezterm's repo with a discussion
about setting the colour of the tab in Wezterm depending on the current working
directory. In that article there was also an interesting configuration snippet
that displayed the icon of the currently running program and more information
in the tab.

## Configuration

### Tab Colour

In the article
[OSC7 and why you might need it](/create/2024-11-19-osc7-and-why-you-might-need-it "OSC7 and why you might need it")
I described how to inform the terminal emulator about the current working directory.
Now we can make use of that information to set the colour of the tab to a colour derived 
from that information.

```lua
-- Return the tab's current working directory
local function get_cwd(tab)
	local pane = tab.active_pane
	if not pane then
		return ""
	end
	local cwd = pane.current_working_dir
	if not cwd then
		return ""
	end
	return cwd.file_path or ""
end

-- Convert arbitrary strings to a unique hex color value
-- Based on: https://stackoverflow.com/a/3426956/3219667
local function string_to_color(str)
	-- Convert the string to a unique integer
	local hash = 0
	for i = 1, #str do
		hash = string.byte(str, i) + ((hash << 5) - hash)
	end

	-- Convert the integer to a unique color
	local hue = (hash & 0x1ff) / 512 * 360
	local saturation = ((hash >> 9) & 255) / 255 * 60
	local c = wezterm.color.from_hsla(hue, saturation, 0.18, 1)
	return c
end

-- On format tab title events, override the default handling to return a custom title
-- Docs: https://wezfurlong.org/wezterm/config/lua/window-events/format-tab-title.html
---@diagnostic disable-next-line: unused-local
wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
	local title = get_tab_title(tab) -- [!code highlight]
	local color = string_to_color(get_cwd(tab))

	if tab.is_active then
		return {
			{ Attribute = { Intensity = "Bold" } },
			{ Background = { Color = color } },
			{ Foreground = { Color = "#ebdbb2" } },
			{ Text = title },
		}
	end
	if has_unseen_output(tab) then
		return {
			{ Foreground = { Color = "#fabd2f" } },
			{ Text = title },
		}
	end
	return title
end)
```

Ignore the highlighted line to get the title, we'll get to that later.

With the `string_to_color` function, we get a 60% saturated colour with 18% lightness,
so that the default foreground color has a good enough contrast without having tabs so
bright, that they would need a dark text colour. This simplifies the functions a bit
compared to the inspiration from the discussion in the issue.

Tabs that are not active are displayed in Wezterm's default title bar colour. They
get a text coloured in yellow, if they have unseen terminal output.

### Tab Title

Now, if we want the title to display the currently running program and the current
dir, we have to dig deeper. Wezterm provides a function, that conveys the program name
via `tab.active_pane.foreground_process_name`. Unfortunately that has two major drawbacks:

1. if we are running a terminal multiplexer in the tab, we would only ever see the name
of the multiplexer
1. under WSL we would ever see the name `wslhost.exe`

That is not very helpful. So we have to turn to the shell's configuration again and 
the `tmux` config. 

`.config/zsh/.zshrc`:

```shell
# set the window title for the shell
function _set_win_title(){
	SHORT_CWD=$(print -P "%20<...<%~%<<")
    echo -ne "\033]0;$SHORT_CWD\007"
}

function _set_wezterm_vars_precmd() {
	__wezterm_set_user_var "WEZTERM_PROG" "zsh"
	__wezterm_set_user_var "WEZTERM_USER" "$(id -un)"
	__wezterm_set_user_var "WEZTERM_HOST" "${WEZTERM_HOSTNAME}"
	# Indicate whether this pane is running inside tmux or not
	if [[ -n "${TMUX-}" ]]; then
		__wezterm_set_user_var "WEZTERM_IN_TMUX" "1"
	else
		__wezterm_set_user_var "WEZTERM_IN_TMUX" "0"
	fi
}

function _set_wezterm_vars_preexec() {
    # Tell wezterm the full command that is being run
    __wezterm_set_user_var "WEZTERM_PROG" "$1"
}

# emit the window title and some user variables 
precmd_functions+=(_set_win_title _set_wezterm_vars_precmd)
preexec_functions+=(_set_wezterm_vars_preexec)
```

We expose the command, that is about to be executed as a user variable
`WEZTERM_PROG` and per default we set the terminal emulator's tab title to the
shortened current working directory. But that can be overridden, e.g. if an
application itself (neovim) sets the title or if `tmux` does that. 

Let's look at those two configs:

`tmux`:

```tmux
# set window titles to command plus pane titles
set -g set-titles on
set -g set-titles-string "[#{=/-10/…:pane_current_command}] #{pane_title}"
# allow programs to set the pane title
set -g allow-set-title on
# automatically set window title
set -wg automatic-rename on
```

The `allow-set-title` directive provides the way for `neovim` to change the title.
And here, we can now expose the command running in the active tab to the title.

`neovim`:

```lua
-- set title string of the terminal. :~ modifier tries to make path relative to HOME
opt.title = true
opt.titlestring = "%.20t%( (%.30{expand(\"%:~:h\")})%)"
```

In `nvim` the tab title is set to the shortened filename and in parenthesis the
abbreviated path to the file (which may be relative to the current dir or completely
unrelated...)

With this in place we can now do some nifty formatting in Wezterm:

```lua
local function format_process(process_name)
	if process_name:find("kubectl") then
		process_name = "kubectl"
	end
	local icon = process_icons[process_name]
	if icon then
		icon = icon .. " "
	end
	return icon or string.format("[%s] ", process_name)
end

-- Pretty format the tab title
local function format_title(tab)
	local apane = tab.active_pane
	local active_title = apane.title
	local process = nil
	local count = 0
	if apane.user_vars.WEZTERM_IN_TMUX == "1" then
		if active_title then
			process, count = string.gsub(active_title, ".*%[(.-)%] .*", "%1")
		end
		if count > 0 then
			process = format_process(process)
			active_title = active_title:gsub(".*%[.-%] (.*)", "%1")
		else
			process = ""
		end
		process = process_icons["tmux"] .. "  " .. process
	else
		process = apane.user_vars.WEZTERM_PROG
		if process then
			process, count = string.gsub(process, "([^ ;]+).*", "%1")
			if count > 0 then
				process = remove_abs_path(process)
				process = format_process(process)
			else
				process = ""
			end
		else
			process = ""
		end
	end

	local description = (not active_title) and "!" or active_title
	return string.format("%s %s", process, description)
end

-- Returns manually set title (from `tab:set_title()` or `wezterm cli set-tab-title`)
-- or creates a new one
local function get_tab_title(tab)
	local title = tab.tab_title
	if title and #title > 0 then
		return title
	end
	return format_title(tab)
end
```

I promised to get back to `get_tab_title`... So usually I do not set the tab title
via wezterm functions, so really I could just call `format_title` directly. I left that
in, for the future...

So the meat of the logic is in `format_title`. If we detect that we are running
inside tmux, we ignore the WEZTERM_PROG variable, because here we would only
get `tmux` back. Instead we parse the command from the tmux-set tile between
the brackets. We force append the tmux icon and then try to set the icon, if
the process is known and possibly a long running command. Short commands
disappear quickly and it does not make much sense to find an icon for every
shell builtin...

![Example Tabs](/articles/assets/2025-09-28-wezterm-tab-info/example_tabs.png)

Here you can see the config in action:

- The first tab runs a `git commit` command in the `~/.local/share/chezmoi/.git` directory
- The second one is an inactive tab with a tmux session, where the active pane runs some
  nodejs command and which has produced some output
- The third tab is a `vim` session editing `raid.log` in my home directory
- The fourth is the active tab running `htop` in my homedir

## Conclusion

It was a little bit tricky to get the various combinations right for getting the most
helpful display of the current command, especially if there are multiple shell layers
involved. In the end this is just a bit eye candy, I am not sure, if this brings really
additional value. There is absolutely no slowdown noticeable from this trickery, neither
in Wezterm, nor in the shell or multiplexer. So I will stick with this for some time and
see whether I like it or remove it again.

