local _M = {}

local utils = require("src.utils")
local lfs = require("lfs")

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

function _M.install_pkgs(t)
    local pkgs = t.content
    if not pkgs or type(pkgs) ~= "table" then
        Log:error("install_pkgs action expect a table")
        return false
    end
    local cmd = "apt-get update && apt-get install -y " .. table.concat(pkgs, " ")
    return utils.run_shell(cmd)
end

function _M.remove_pkgs(t)
    local pkgs = t.content
    if not pkgs or type(pkgs) ~= "table" then
        Log:error("remove_pkgs action expect a table")
        return false
    end
    local cmd = "apt-get remove -y " .. table.concat(pkgs, " ")
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
    local attr = lfs.attributes(path)
    return attr and attr.mode == "file"
end

function _M.testdir(t)
    local path = t.content.path
    if not path then
        Log:error("testdir action requires 'path'")
        return false
    end
    local attr = lfs.attributes(path)
    return attr and attr.mode == "directory"
end

function _M.mkdir(t)
    local path = t.content.path
    if not path then
        Log:error("mkdir action requires 'path'")
        return false
    end
    local cmd = string.format("mkdir -p %s", path)
    return utils.run_shell(cmd)
end

function _M.link(t)
    local src = t.content.src
    local dst = t.content.dst
    local symlink = t.content.symlink
    if not src or not dst then
        Log:error("link action requires 'src' and 'dst'")
        return false
    end
    return lfs.link(src, dst, symlink) -- 如果symlink为true则创建符号链接，否则创建硬链接
end

function _M.chmod(t)
    local path = t.content.path
    local mode = t.content.mode
    if not path or not mode then
        Log:error("chmod action requires 'path' and 'mode'")
        return false
    end
    local cmd = string.format("chmod %s %s", mode, path)
    return utils.run_shell(cmd)
end

function _M.chown(t)
    local path = t.content.path
    local user = t.content.user
    local group = t.content.group
    if not path or not user then
        Log:error("chown action requires 'path' and 'user'")
        return false
    end
    local cmd = string.format("chown %s:%s %s", user, group or user, path)
    return utils.run_shell(cmd)
end

--- 高级action
--- 这部分是对基本action的组合
function _M.apply_config_file(t)
    local src = t.content.src
    local dst = t.content.dst

    local action = {
        name = "apply config file",
        pre = {
            name = "check if config file exists",
            action = "testfile",
            content = {
                path = src
            }
        },
        action = "cp",
        content = {
            src = src,
            dst = dst
        },
        post = {
            name = "check if config file was copied",
            action = "testfile",
            content = {
                path = dst
            }
        }
    }
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
