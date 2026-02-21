#! /bin/env lua5.4

local function is_rel_path(path)
    return not string.match(path, "^/")
end

-- 提供相对require的能力
PATH = string.match(arg[0], "^(.+)/[^/]+$") .. "/"
-- 判断是否为绝对路径
if is_rel_path(PATH) then
    PATH = os.getenv("PWD") .. "/" .. PATH
end
-- 使脚本可以从任意路径启动
package.path = ('%s?.lua;%s'):format(PATH, package.path)

-- 加载模块
local utils = require("src.utils")
local commands = require("src.commands")
local operations = require("src.operations")
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

-- 预定义一个需要处理的模块列表
local managed_modules = {}

--- 参数检查
_ = commands[arg[1]]
-- 如果提供了参数2，则直接替换base.cfg.lua中的managed列表
if arg[2] then
    managed_modules = utils.split(arg[2], ",")
end

--- 正式启动
Log:info("confman started")

--- 加载基础配置
Log:info("loading base config...")
local base_cfg = utils.load_cfg("base.cfg.lua")
if not base_cfg then
    Log:error("failed to load base config, exiting")
    os.exit(1)
end

-- 如果没有通过命令行参数覆盖，则使用配置文件中的managed列表
if #managed_modules == 0 then
    managed_modules = base_cfg.managed or {}
end

Log:info(#managed_modules .. " modules to manage: " .. table.concat(managed_modules, ", "))

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


local success_count = 0

--- 正式处理
for i, module in ipairs(managed_modules) do
    Log:info(string.format("processing module %d/%d: %s", i, #managed_modules, module))
    if utils.indented(operations.process_module(module, arg[1])) then
        success_count = success_count + 1
    end
end

Log:info(string.format("completed processing %d/%d modules successfully", success_count, #managed_modules))
