--- 高级action
--- 这部分是对基本action的组合

local actions = require("src.actions")
local utils = require("src.utils")

local _M = {}
local high_level_actions = setmetatable({}, {
    __index = function(_, k)
        if _M[k] then -- 先在high-level里找
            return function(...)
                local args = { ... }

                --- 找到了就当action里跑
                --- 因为这里的函数本质上是action构建器
                Log:debug("action details: ")
                require("src.utils").print_table(_M[k](table.unpack(args)), function(...) Log:debug(...) end)
                return utils.indented(
                    require("src.operations").execute_action_or_list(
                        _M[k](
                            table.unpack(args)
                        )
                    )
                )
            end
        else
            return actions[k] -- 没找到就退回去找基本action
        end
    end
})

function _M.apply_config_file(t)
    local src = t.content.src
    local dst = t.content.dst

    Log:debug(string.format("Applying config file from '%s' to '%s'", src, dst))

    return {
        name = "apply config file",
        pre = {
            {
                name = "soft wrap",
                action = "soft",
                content = {
                    name = "check if config dir exists",
                    action = "testdir",
                    content = {
                        path = utils.dirname(dst)
                    },
                    onfail = {     -- 如果目录不存在则创建目录
                        name = "create config dir",
                        action = "mkdir",
                        content = {
                            path = utils.dirname(dst)
                        }
                    }
                }
            },
            {
                name = "check src file exists",
                action = "testfile",
                content = {
                    path = src
                }
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

return high_level_actions
