local _M = {}

local utils = require("src.utils")

function _M.soft(t)
    utils.indented(
        require("src.operations").execute_action(t.content) -- 延迟加载避免循环依赖
    )
    return true                                             -- 无论结果如何都返回成功，继续执行后续步骤
end

function _M.cp(t)
    local src = t.content.src
    local dst = t.content.dst
    if not src or not dst then
        Log:error("cp action requires 'src' and 'dst'")
        return false
    end
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

function _M.systemd(t)
    local verb = t.content.verb
    local service = t.content.service
    if not verb or not service then
        Log:error("systemd action requires 'verb' and 'service'")
        return false
    end
    if not supported_systemd_actions[verb] then
        Log:error("unsupported systemd verb '" .. verb .. "'")
        return false
    end
    local cmd = string.format("systemctl %s %s", verb, service)
    return utils.run_shell(cmd)
end

function _M.cmd(t)
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

function _M.testfile(t)
    local path = t.content.path
    if not path then
        Log:error("testfile action requires 'path'")
        return false
    end
    return utils.is_file_exist(path)
end

-- 兜底
setmetatable(_M, {
    __index = function(_, key)
        return function(t)
            Log:error("unsupported action '" .. key .. "', skipping")
            if type(t) == "table" then
                Log:debug("action details: ")
                utils.print_table(t, function(...) Log:debug(...) end)
            else
                Log:debug("action is not a table: " .. type(t))
            end
            return false
        end
    end
})

return _M
