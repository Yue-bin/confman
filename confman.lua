#! /bin/env lua

-- 加载模块
local utils = require("src.utils")
--- 全局日志
local ansicolors = require("ansicolors") -- https://github.com/kikito/ansicolors.lua
local ll = require("logging")
-- 颜色映射
local level_colors = {
    [ll.DEBUG] = { bright = "cyan bright", normal = "cyan" },
    [ll.INFO]  = { bright = "white bright", normal = "white" },
    [ll.WARN]  = { bright = "yellow bright", normal = "yellow" },
    [ll.ERROR] = { bright = "red bright", normal = "red" },
    [ll.FATAL] = { bright = "magenta bright", normal = "magenta" },
}

ll.defaultLogger(ll.new(function(self, level, message)
    local colors = level_colors[level] or level_colors[ll.DEBUG]
    local indent = utils.get_indent() -- 每次调用时动态获取！
    local ts = os.date("%y-%m-%d %H:%M:%S")

    local line = ansicolors(string.format(
        "%%{%s}%s %s\t%s%%{reset}%%{%s}%s%%{reset}",
        colors.bright, ts, level,
        indent,
        colors.normal, message
    ))

    io.stderr:write(line .. "\n")
    return true
end))

Log = ll.defaultLogger()


--- 正式启动
Log:info("confman started")

--- 加载基础配置
Log:info("loading base config...")
local base_cfg = utils.load_cfg("base.cfg.lua")
if not base_cfg then
    Log:error("failed to load base config, exiting")
    os.exit(1)
end

Log:info(#base_cfg.managed .. " modules to manage: " .. table.concat(base_cfg.managed, ", "))

-- 修改日志等级
local new_log_level = ll.INFO
if base_cfg.loglevel then
    if ll[base_cfg.loglevel] then
        new_log_level = ll[base_cfg.loglevel]
    else
        Log:warn("unknown log level '" .. base_cfg.loglevel .. "', using default INFO")
    end
end
Log:setLevel(new_log_level)
Log:info("log level set to " .. new_log_level)


--- 正式处理
for i, module in ipairs(base_cfg.managed) do
    Log:info(string.format("processing module %d/%d: %s", i, #base_cfg.managed, module))

    utils.indented(function()
        local mod = utils.safe_require(module)
        if not mod then
            Log:error("failed to load module " .. module .. ", skipping")
            goto continue
        end

        if not mod.install then
            Log:error("module " .. module .. " does not have an install table, skipping")
            goto continue
        end

        for j, step in ipairs(mod.install) do
            Log:info(string.format("module %s: executing step %d/%d '%s'", module, j, #mod.install, step.name))

            utils.indented(function()
                local action_func = require("src.actions")[step.action]
                if not action_func then
                    Log:error("unsupported action '" .. step.action .. "' in module " .. module .. ", skipping step")
                    goto continue_step
                end

                local ok = action_func(module, step)
                if not ok then
                    Log:error(string.format("module %s: step '%s' failed", module, step.name))
                    goto continue_step
                end

                ::continue_step::
            end)
        end
        ::continue::
    end)
end
