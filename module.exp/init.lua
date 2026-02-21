local _M = {}

-- 安装模块
_M.install = {
    {
        name = "install expmod",
        action = "install_pkgs",
        content = {
            "expmod" -- 包名，可以添加多个
        }
    }
}

-- 配置模块，按顺序执行，每项一个table
_M.apply = {
    {
        name = "install config", -- 名字，日志会用到
        pre =                    -- 可选的预操作，是一个action或者actionlist，而且可以无限套娃
        {
            name = "check if config dir exists",
            pre = { -- 套娃
                {
                    name = "soft fail",
                    action = "soft",
                    content = {
                        name = "check if dir exists",
                        action = "testdir",
                        content = {
                            path = "/etc/expmod"
                        },
                        onfail = { -- 失败钩子
                            name = "create config dir",
                            action = "mkdir",
                            content = {
                                "/etc/expmod"
                            }
                        },
                    },
                },
                {
                    name = "check if im sudo",
                    action = "cmd",
                    content = {
                        "id -u | grep -q 0"
                    }
                }
            },
            post = { -- 可选的后检查，格式同precheck
                name = "check if config file was copied",
                action = "testfile",
                content = {
                    path = "/etc/expmod/expmod.conf"
                }
            },
            action = "cp",           -- 执行的动作
            content = {
                src = "expmod.conf", -- 采用相对路径
                dst = "/etc/expmod/expmod.conf"
            }
        },
        {
            -- 这会变成 `systemctl restart expmod`
            name = "restart expmod",
            action = "systemd",
            content = {
                action = "restart",
                service = "expmod"
            }
        },
        {
            name = "some commands",
            action = "cmd",
            content = {
                "echo 'hello world'", -- 这会被当成shell命令执行
                "ls -l /etc/expmod/expmod.conf"
            }
        }
    },
}

_M.remove = {
    {
        name = "remove expmod",
        action = "remove_pkgs",
        content = {
            "expmod" -- 包名，可以添加多个
        }
    }
}

return _M
