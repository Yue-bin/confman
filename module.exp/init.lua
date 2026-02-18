local _M = {}

-- 安装模块，按顺序执行，每项一个table
_M.install = {
    {
        name = "install config", -- 名字，日志会用到
        action = "cp",           -- 执行的动作
        content = {
            src = "expmod.conf", -- 采用同级目录路径，会在其它地方处理
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
            {
                "echo 'hello world'", -- 这会被当成shell命令执行
            },
            {
                "ls -l /etc/expmod/expmod.conf"
            }
        }
    }
}

return _M
