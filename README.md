# Gitlab CodeOwners 
Read through the gitlab's codeowners format. Easily see the owner of each file.

## Installation

### Lazy.nvim 
using this
```lua
{
    "vzsky/gitlab-codeowners.nvim", opts = {}
}
```
will set a command `GitlabCodeowners` that shows all code owners of the opening buffer.

### With Lualine
```lua
lualine_x = {
    function ()
        local co = require("gitlab-codeowners").short_codeowners() -- or codeowners()
        if not co then return "" else return co end
    end,
    -- filetype, add other stuffs, ...
},


```
