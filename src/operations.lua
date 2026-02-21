local _M = {}

-- 全部包装成函数工厂
local operations = setmetatable({}, {
    __index = function(_, k)
        if _M[k] then
            return function(...)
                local args = { ... }
                return function()
                    return _M[k](table.unpack(args))
                end
            end
        else
            Log:error("Unknown operation: '" .. tostring(k) .. "'")
            return function() end -- 返回一个空函数，避免调用时出错
        end
    end
})

local utils = require("src.utils")
local actions = require("src.actions")

--- 处理单个模块的函数工厂
--- @param module string 模块名称
--- @param command string 操作命令
--- @return boolean 是否成功
function _M.process_module(module, command)
    Log:debug(string.format("Processing module '%s' with command '%s'", module, command))
    -- 检查是否使用了保留名
    if module == "src" then
        Log:error("module name '" .. module .. "' is reserved, skipping")
        return false
    end
    local mod = utils.safe_require(module)
    if not mod then
        module = module or ""
        Log:error("failed to load module '" .. module .. "', skipping")
        return false
    end

    if not mod[command] then
        Log:error("module '" .. module .. "' does not have an '" .. command .. "' table, skipping")
        return false
    end

    local success_count = 0
    for j, step in ipairs(mod[command]) do
        Log:info(string.format("module %s: executing step %d/%d '%s'", module, j, #mod[command], step.name))

        if utils.indented(operations.execute_step(module, step)) then
            success_count = success_count + 1
        else
            Log:error(string.format("module %s: step '%s' failed, aborting module", module, step.name))
            Log:info(string.format("module %s: completed %d/%d steps successfully", module, success_count, #mod[command]))
            return false
        end
    end
    Log:info(string.format("module %s: completed %d/%d steps successfully", module, success_count, #mod[command]))
    return success_count == #mod[command]
end

--- 处理单个action的函数
--- @param module string 模块名称
--- @param step table 包含action信息的表
--- @return boolean 是否成功
function _M.execute_step(module, step)
    Log:debug(string.format("Executing step '%s' of module '%s' with action '%s'", step.name, module, step.action))

    local action_func = actions[step.action]
    if not action_func then
        Log:error("unsupported action '" .. step.action .. "' in module " .. module .. ", skipping step")
        return false
    end

    local ok = action_func(module, step)
    if not ok then
        Log:error(string.format("module %s: step '%s' failed", module, step.name))
        return false
    end

    Log:info(string.format("module %s: step '%s' completed successfully", module, step.name))
    return true
end

return operations
