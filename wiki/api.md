## API

### Functions

| Function | Description |
| -------- | ----------- |
| `plug#begin(path)` | Start vim-plug block |
| `plug#(...)` | Register a plugin (equivalent to `Plug` command) |
| `plug#end()` | End block, update &rtp, and load plugins when not `vim_starting` |
| `plug#helptags()` | Regenerate help tags for all plugins |
| `plug#load(names...)` | Load the plugins immediately |
| `plug#load(name_list)` | Load the plugins immediately |

### Global variables (read-only)

| Variable | Type | Description |
| -------- | ---- | ----------- |
| `g:plug_home` | String | Directory to store/load plugins. Set by `plug#begin(path)` call. |
| `g:plugs` | Dict | Information of plugins. Initialized by `plug#begin(path)` and incrementally extended by `Plug` commands. |

### Autocmds

| Event  | Pattern          | Description                              |
| ------ | ---------------- | ---------------------------------------- |
| `User` | Name of a plugin | Triggered when the plugin is lazy-loaded |

### Mappings

| Name | Description |
| --- | --- |
| `<plug>(plug-preview)` | Opens preview window for the commit on the current line (see [#769](https://github.com/junegunn/vim-plug/pull/769)) |