local _M = {}

local utils = require("src.utils")


-- 兜底
setmetatable(_M, {
    __index = function(_, key)
        return function(t)
            Log:error("unsupported action '" .. key .. "', skipping")
            Log:debug("action details: ")
            utils.print_table(t, function(...) Log:debug(...) end)
            return false
        end
    end
})

return _M
