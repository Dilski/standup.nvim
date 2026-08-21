# standup.nvim

A tiny Neovim plugin to run a stand-up. It opens a scratch buffer with your
team, lets you tick people off as they talk, and can pick the next speaker at
random.

- Tick / untick a participant. Ticked names sink to the bottom and get a
  strike-through highlight.
- Jump to a random person who has not talked yet.
- Load teams from plain text files or define them inline in your config.

## Requirements

- Neovim >= 0.9

## Installation

### lazy.nvim / LazyVim

Add a spec file (for LazyVim, drop it in `~/.config/nvim/lua/plugins/`):

```lua
return {
  "Dilski/standup.nvim",
  cmd = "Standup",
  opts = {
    -- Optional. Define teams inline instead of using text files.
    templates = {
      team = { "Ada", "Grace", "Alan" },
    },
  },
}
```

`opts` is passed straight to `require("standup").setup()`, so `opts = {}` works
too when you only use text-file templates.

### packer.nvim

```lua
use({
  "Dilski/standup.nvim",
  config = function()
    require("standup").setup()
  end,
})
```

## Templates

A template is a named list of participants. You can define them two ways; both
sources merge, and files win on a name clash.

### From text files

Put one file per team in `templates_dir` (default `~/.config/standup`), named
`<name>.txt`, with one participant per line:

```
# ~/.config/standup/team.txt
Ada
Grace
Alan
```

### Inline

```lua
opts = {
  templates = {
    team = { "Ada", "Grace", "Alan" },
    guild = { "Edsger", "Donald", "Barbara" },
  },
}
```

## Usage

| Command          | Action                                              |
| ---------------- | --------------------------------------------------- |
| `:Standup`       | Pick a template (skips the prompt if only one).     |
| `:Standup <name>`| Open a specific template. Tab-completion is wired.  |

### Buffer keys

| Key | Action                             |
| --- | ---------------------------------- |
| `t` | Tick / untick the current line.    |
| `r` | Jump to a random unticked person.  |
| `q` | Close the standup buffer.          |

## Configuration

Defaults:

```lua
require("standup").setup({
  templates_dir = vim.fn.expand("~/.config/standup"),
  templates = {},
  keymaps = {
    toggle = "t",
    random = "r",
    close = "q",
  },
})
```

## License

MIT. See [LICENSE](LICENSE).
