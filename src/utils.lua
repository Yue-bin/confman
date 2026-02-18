local _M = {}

--- 用于加载cfg.lua这种内部包含裸table和值的配置文件
--- @param path string 配置文件路径
--- @return table? 配置表，或nil表示加载失败
function _M.load_cfg(path)
    Log:debug("loading config from " .. path)
    local config = {}
    local chunk, err = loadfile(path, "t", config)
    if not chunk then
        Log:error("failed to load config file: " .. err)
        return nil
    end

    local ok, result = pcall(chunk)
    if not ok then
        Log:error("failed to execute config file: " .. result)
        return nil
    end

    return config
end

--- 安全地require
--- @param module_name string 模块名
--- @return table? 模块表，或nil表示加载失败
function _M.safe_require(module_name)
    Log:debug("safely requiring module " .. module_name)
    local ok, result = pcall(require, module_name)
    if not ok then
        Log:error("failed to require module " .. module_name .. ": " .. result)
        return nil
    end

    return result
end

local cur_indent = 0
--- 打印日志时提供当前缩进层级
--- @return string 当前缩进字符串
function _M.get_indent()
    return string.rep("  ", cur_indent)
end

function _M.indented(fn)
    cur_indent = cur_indent + 1
    local ok, err = pcall(fn)
    cur_indent = cur_indent - 1 -- 即使 fn 出错也会恢复
    if not ok then
        Log:error("error in indented block: " .. tostring(err))
    end
end

--- 打印table，递归展开
--- @param table table 要打印的table
--- @param print_func? function 用于输出的函数，默认为print
--- @param key? string 当前table在父table中的key，内部使用
function _M.print_table(table, print_func, key)
    print_func = print_func or print
    key = key or ""

    _M.indented(function()
        if key ~= "" then
            print_func(key .. " = {")
        else
            print_func("{")
        end

        for k, v in pairs(table) do
            if type(v) == "table" then
                _M.print_table(v, print_func, k)
            else
                print_func(string.format("%s%s = %s", "  ", tostring(k), tostring(v)))
            end
        end

        print_func("}")
    end)
end

--- 安全地执行shell命令，捕获输出和错误，纯aigc
local unistd = require("posix.unistd")
local wait = require("posix.sys.wait")

local BUF_SIZE = 4096

--- 从文件描述符中读取全部数据
--- @param fd number 文件描述符
--- @return string 读取到的全部数据
local function read_all(fd)
    local chunks = {}
    while true do
        local data, err = unistd.read(fd, BUF_SIZE)
        if data == nil then
            -- 读取出错，跳出
            break
        end
        if #data == 0 then
            -- EOF
            break
        end
        chunks[#chunks + 1] = data
    end
    return table.concat(chunks)
end

--- 安全地执行shell命令，分别捕获 stdout、stderr 和退出码
--- @param cmd string 命令字符串
--- @return boolean success   是否执行成功（退出码为0）
--- @return string  stdout    命令的标准输出
--- @return string  stderr    命令的标准错误输出
--- @return string  exit_type "exit" 或 "signal"
--- @return number  code      退出码或信号编号
function _M.run_shell(cmd)
    Log:debug("running shell: " .. cmd)

    -- 创建 stdout 管道
    local stdout_r, stdout_w = unistd.pipe()
    if not stdout_r then
        local msg = "failed to create stdout pipe: " .. tostring(stdout_w)
        Log:error(msg)
        return false, "", msg, "exit", -1
    end

    -- 创建 stderr 管道
    local stderr_r, stderr_w = unistd.pipe()
    if not stderr_r then
        local msg = "failed to create stderr pipe: " .. tostring(stderr_w)
        Log:error(msg)
        unistd.close(stdout_r)
        unistd.close(stdout_w)
        return false, "", msg, "exit", -1
    end

    -- fork 子进程
    local pid, fork_err = unistd.fork()

    if pid == nil then
        -- fork 失败
        local msg = "fork failed: " .. tostring(fork_err)
        Log:error(msg)
        unistd.close(stdout_r)
        unistd.close(stdout_w)
        unistd.close(stderr_r)
        unistd.close(stderr_w)
        return false, "", msg, "exit", -1
    end

    if pid == 0 then
        -----------------------------------------------
        -- 子进程
        -----------------------------------------------
        -- 关闭不需要的读端
        unistd.close(stdout_r)
        unistd.close(stderr_r)

        -- 将 stdout_w 重定向到 STDOUT，stderr_w 重定向到 STDERR
        unistd.dup2(stdout_w, unistd.STDOUT_FILENO)
        unistd.dup2(stderr_w, unistd.STDERR_FILENO)

        -- 重定向完成后关闭原始 fd
        unistd.close(stdout_w)
        unistd.close(stderr_w)

        -- 通过 sh -c 执行命令
        local ok, err = unistd.execp("/bin/bash", { "-c", cmd })
        -- execp 成功不会返回，走到这里说明失败了
        unistd._exit(127)
    end

    -----------------------------------------------
    -- 父进程
    -----------------------------------------------
    -- 关闭不需要的写端（重要！否则 read 不会收到 EOF）
    unistd.close(stdout_w)
    unistd.close(stderr_w)

    -- 读取子进程的 stdout 和 stderr
    local stdout = read_all(stdout_r)
    local stderr = read_all(stderr_r)

    -- 关闭读端
    unistd.close(stdout_r)
    unistd.close(stderr_r)

    -- 等待子进程结束，获取退出状态
    local _, reason, status = wait.wait(pid)
    -- reason: "exited", "killed", "stopped"
    -- status: 退出码 或 信号编号

    local exit_type = (reason == "exited") and "exit" or "signal"
    local code = status or -1
    local success = (reason == "exited" and code == 0)

    if not success then
        Log:error(string.format(
            "shell command failed: %s (exit_type: %s, code: %d, stderr: %s)",
            cmd, exit_type, code, stderr
        ))
    end

    return success, stdout, stderr, exit_type, code
end

return _M
