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
local actions = require("src.high-level-actions")

--- 处理单个模块的函数工厂
--- @param module string 模块名称
--- @param command string 操作命令
--- @return boolean success 是否成功
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


    return utils.indented(
        operations.execute_action_or_list(mod[command])
    )
end

--- 处理单个action的函数
--- @param action table 包含action信息的表
--- @return boolean success 是否成功
function _M.execute_action(action)
    Log:debug(string.format("Executing action '%s'", action.name))

    local action_func = actions[action.action]

    -- 若有pre，则先执行pre
    if action.pre then
        Log:info(string.format("Executing pre-check for action '%s'", action.name))
        local ok = utils.indented(operations.execute_action_or_list(action.pre))
        if not ok then
            Log:error(string.format("pre-check for action '%s' failed, skipping main action", action.name))
            return false
        end
    end

    -- 运行主action
    local ok = action_func(action)
    if not ok then
        Log:error(string.format("action '%s' failed", action.name))

        -- 若有onfail，则执行onfail
        if action.onfail then
            Log:info(string.format("Executing onfail action for action '%s'", action.name))
            utils.indented(operations.execute_action_or_list(action.onfail))
        end
        return false
    end

    -- 若有onsuccess，则执行onsuccess
    if action.onsuccess then
        Log:info(string.format("Executing onsuccess action for action '%s'", action.name))
        utils.indented(operations.execute_action_or_list(action.onsuccess))
    end

    -- 若有post，则执行post
    if action.post then
        Log:info(string.format("Executing post-check for action '%s'", action.name))
        local ok = utils.indented(operations.execute_action_or_list(action.post))
        if not ok then
            Log:error(string.format("post-check for action '%s' failed", action.name))
            return false
        end
    end

    Log:info(string.format("action '%s' completed successfully", action.name))
    return true
end

--- 处理action或者action列表的函数
--- @param action_or_list table 单个action表或包含多个action的table
--- @return boolean success 是否成功
function _M.execute_action_or_list(action_or_list)
    utils.print_table(action_or_list, function(...) Log:debug(...) end)
    for _, action_item in utils.action_iterator(action_or_list) do
        Log:debug(string.format("Processing action item '%s'", action_item.name))
        local ok = utils.indented(operations.execute_action(action_item))
        if not ok then
            return false
        end
    end
    return true
end

return operations
