local _M = {}

local utils = require("src.utils")

function _M.cp(mod, t)
    local src = t.content.src
    local dst = t.content.dst
    if not src or not dst then
        Log:error("cp action requires 'src' and 'dst'")
        return false
    end
    -- 默认相对路径
    src = mod .. "/" .. src
    local cmd = string.format("cp %s %s", src, dst)
    return utils.run_shell(cmd)
end

local supported_systemd_actions = {
    start = true,
    stop = true,
    restart = true,
    reload = true,
    enable = true,
    disable = true,
}

function _M.systemd(_, t)
    local action = t.content.action
    local service = t.content.service
    if not action or not service then
        Log:error("systemd action requires 'action' and 'service'")
        return false
    end
    if not supported_systemd_actions[action] then
        Log:error("unsupported systemd action '" .. action .. "'")
        return false
    end
    local cmd = string.format("systemctl %s %s", action, service)
    return utils.run_shell(cmd)
end

function _M.cmd(_, t)
    if not t.content then
        Log:error("cmd action requires 'content'")
        return false
    end
    local success = true
    for _, cmd in ipairs(t.content) do
        local ok, stdout, stderr, exit_type, code = utils.run_shell(cmd)
        if not ok then
            Log:error("command failed: " ..
                cmd .. " (exit_type: " .. exit_type .. ", code: " .. code .. ", stderr: " .. stderr .. ")")
            success = false
        end

        Log:info("command succeeded: " .. cmd .. " (stdout: " .. stdout .. ")")
    end
    return success
end

-- 兜底
setmetatable(_M, {
    __index = function(_, key)
        return function(_, t)
            Log:error("unsupported action '" .. key .. "', skipping")
            Log:debug("action details: ")
            utils.print_table(t, function(...) Log:debug(...) end)
            return false
        end
    end
})

return _M
