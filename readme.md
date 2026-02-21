# confman – VPS 配置管理工具

confman 是一个用 Lua 编写的轻量级 VPS 配置管理工具，灵感来自 systemd 的单元文件概念，但采用 Lua 模块化的设计。它允许你通过声明式步骤定义服务的安装、配置和移除，并支持依赖检查、条件执行和嵌套动作。

目前仅支持Debian系，因为我在服务器上只用这个

## 特性

- **声明式配置**：每个模块使用 Lua 表格描述安装、应用配置、移除的步骤。
- **灵活的动作系统**：内置 `cp`、`systemd`、`install_pkgs`、`remove_pkgs`、`cmd`、`testfile`、`testdir`、`mkdir`、`link`、`chmod`、`chown`、`soft` 等动作，支持 `pre`/`post`/`onfail`/`onsuccess` 钩子。
- **模块化组织**：每个服务（或一组相关任务）作为一个独立模块，便于复用和分享。
- **详细的彩色日志**：通过 `ansicolors` 和 `logging` 库提供带缩进、时间戳的彩色输出，便于调试。
- **安全执行**：使用 `posix` 库进行安全的 shell 命令执行，捕获 stdout/stderr 和退出码。
- **轻量依赖**：仅需 Lua 5.4 及几个常用库（lua-logging、lua-posix、lua-ansicolors、lua-filesystem）。

## 安装依赖

在 Debian/Ubuntu 系统上，运行项目根目录的初始化脚本：

```bash
./init.sh
```

该脚本会安装所需的 Lua 包：

- `lua5.4`
- `lua-logging`
- `lua-posix`
- `lua-ansicolors`
- `lua-filesystem`

## 快速开始

1. **复制基础配置模板**：

   ```bash
   cp base.cfg.lua{.exp,}
   ```

   然后编辑 `base.cfg.lua`，在 `managed` 列表中填写你要管理的模块名（例如 `"sing-box"`、`"fail2ban"`）。

2. **创建模块目录**：

   每个模块是一个文件夹，其中必须包含一个 `init.lua` 文件。你可以复制示例模块：

   ```bash
   cp -r module.exp my-service
   ```

   然后修改 `my-service/init.lua` 定义你的步骤。

3. **运行 confman**：

   ```bash
   ./confman.lua apply   # 应用配置
   ./confman.lua install # 安装服务
   ./confman.lua remove  # 移除服务
   ```

   你可以通过第二个参数临时覆盖 `managed` 列表：

   ```bash
   ./confman.lua apply sing-box,fail2ban
   ```

## 配置

### 基础配置 (`base.cfg.lua`)

这是一个 Lua 文件，返回一个包含以下字段的表：

```lua
-- 需要处理的模块名称，会按顺序处理
managed = {
    "sing-box",
    "fail2ban"
}

-- 日志等级（DEBUG、INFO、WARN、ERROR、FATAL）
loglevel = "DEBUG"
```

模板文件 `base.cfg.lua.exp` 提供了相同的结构，你可以直接复制并修改。

### 模块配置

每个模块的 `init.lua` 必须返回一个表，其中可以包含以下键（每个键对应一个命令）：

- `install`：安装服务所需的步骤（例如安装软件包、创建目录）。
- `apply`：应用配置文件的步骤（例如复制配置文件、重启服务）。
- `remove`：移除服务时的清理步骤（例如卸载软件包、删除文件）。

每个键的值是一个由 **动作表（action table）** 组成的数组，按顺序执行。

## 动作表格式

动作表是一个 Lua 表，包含以下字段：

| 字段 | 类型 | 必选 | 说明 |
|------|------|------|------|
| `name` | string | 是 | 步骤的名称，用于日志输出。 |
| `action` | string | 是 | 要执行的动作类型，如 `"cp"`、`"systemd"`、`"install_pkgs"` 等。 |
| `content` | any | 是 | 动作所需的参数，具体格式因动作而异。 |
| `pre` | table | 否 | 一个可选的子动作，在主动作之前执行；若失败则跳过主动作。 |
| `post` | table | 否 | 一个可选的子动作，在主动作之后执行；若失败则标记该步骤为失败。 |
| `onfail` | table | 否 | 可选的动作，当主动作失败时执行。 |
| `onsuccess` | table | 否 | 可选的动作，当主动作成功时执行。 |

### 内置动作

#### `cp`

复制文件。

```lua
{
    name = "copy config",
    action = "cp",
    content = {
        src = "my.conf",   -- 源文件（相对模块目录）
        dst = "/etc/my.conf"
    }
}
```

#### `systemd`

控制系统服务。

```lua
{
    name = "restart service",
    action = "systemd",
    content = {
        verb = "restart",   -- start|stop|restart|reload|enable|disable
        service = "nginx"
    }
}
```

#### `install_pkgs` / `remove_pkgs`

使用 apt 安装或移除软件包。

```lua
{
    name = "install packages",
    action = "install_pkgs",
    content = { "nginx", "curl", "vim" }
}
```

#### `cmd`

执行一条或多条 shell 命令。

```lua
{
    name = "run commands",
    action = "cmd",
    content = {
        "echo 'Hello'",
        "ls -la /etc"
    }
}
```

#### `testfile`

检查文件是否存在。

```lua
{
    name = "check config",
    action = "testfile",
    content = {
        path = "/etc/nginx/nginx.conf"
    }
}
```

#### `testdir`

检查目录是否存在。

```lua
{
    name = "check directory",
    action = "testdir",
    content = {
        path = "/etc/nginx"
    }
}
```

#### `mkdir`

创建目录（如果不存在则创建父目录）。

```lua
{
    name = "create directory",
    action = "mkdir",
    content = {
        path = "/etc/myapp"
    }
}
```

#### `link`

创建硬链接或符号链接。

```lua
{
    name = "create symlink",
    action = "link",
    content = {
        src = "/path/to/source",
        dst = "/path/to/link",
        symlink = true   -- 可选，默认为false（硬链接）
    }
}
```

#### `chmod`

修改文件或目录的权限。

```lua
{
    name = "change permissions",
    action = "chmod",
    content = {
        path = "/etc/myapp/config.conf",
        mode = "644"
    }
}
```

#### `chown`

修改文件或目录的所有者和组。

```lua
{
    name = "change ownership",
    action = "chown",
    content = {
        path = "/etc/myapp/config.conf",
        user = "www-data",
        group = "www-data"   -- 可选，默认与user相同
    }
}
```

#### `soft`

“软”动作：即使子动作失败，也继续执行后续步骤。通常用于可选的预检查。

```lua
{
    name = "optional check",
    action = "soft",
    content = {
        name = "check if root",
        action = "cmd",
        content = { "id -u | grep -q 0" }
    }
}
```

### 高级动作

高级动作是对基本动作的组合，提供更复杂的逻辑。

#### `apply_config_file`

复制配置文件，并在复制前自动检查目标目录是否存在（若不存在则创建），复制后验证文件是否成功复制。

```lua
{
    name = "apply config file",
    action = "apply_config_file",
    content = {
        src = "myapp.conf",
        dst = "/etc/myapp.conf"
    }
}
```

### 嵌套动作

`pre`、`post`、`onfail` 和 `onsuccess` 字段本身也都是完整的动作表，因此可以无限嵌套，实现复杂的条件逻辑。

## 模块示例

下面是一个完整的模块示例（假设模块名为 `myapp`）：

```lua
local _M = {}

_M.install = {
    {
        name = "install myapp",
        action = "install_pkgs",
        content = { "myapp" }
    }
}

_M.apply = {
    {
        name = "copy config",
        pre = {
            name = "ensure config exists",
            action = "testfile",
            content = { path = "myapp.conf" }
        },
        action = "cp",
        content = {
            src = "myapp.conf",
            dst = "/etc/myapp.conf"
        },
        post = {
            name = "verify copy",
            action = "testfile",
            content = { path = "/etc/myapp.conf" }
        }
    },
    {
        name = "restart service",
        action = "systemd",
        content = {
            verb = "restart",
            service = "myapp"
        }
    }
}

_M.remove = {
    {
        name = "remove myapp",
        action = "remove_pkgs",
        content = { "myapp" }
    }
}

return _M
```

将该文件保存为 `myapp/init.lua`，然后在 `base.cfg.lua` 的 `managed` 列表中加入 `"myapp"` 即可。

## 命令参考

```
./confman.lua <command> [module1,module2,...]
```

- `command`：必须是 `install`、`apply`、`remove` 之一。
- 第二个参数（可选）是以逗号分隔的模块名列表，用于临时覆盖 `base.cfg.lua` 中的 `managed` 列表。

示例：

```bash
# 安装所有在 base.cfg.lua 中配置的模块
./confman.lua install

# 仅对 sing-box 和 fail2ban 应用配置
./confman.lua apply sing-box,fail2ban

# 移除名为 testmod 的模块
./confman.lua remove testmod
```

## 项目结构

```
.
├── confman.lua          # 主入口
├── base.cfg.lua         # 主配置文件（由模板复制而来）
├── base.cfg.lua.exp     # 配置模板
├── init.sh              # 依赖安装脚本
├── src/                 # 内部模块（保留名称，用户不要使用）
│   ├── utils.lua        # 工具函数
│   ├── actions.lua      # 动作实现
│   ├── high-level-actions.lua # 高级动作组合
│   ├── operations.lua   # 模块处理逻辑
│   └── commands.lua     # 命令验证
├── module.exp/          # 示例模块
│   ├── init.lua
│   └── expmod.conf
├── testmod/             # 测试模块
│   ├── init.lua
│   └── testmod.conf
└── README.md            # 本文档
```

## 注意事项

- 模块目录名不能为 `src`，该名称被保留用于内部代码。
- 配置文件（`*.cfg.lua`）使用 Lua 语法，直接返回一个表；模板文件（`*.cfg.lua.exp`）仅供复制。
- 日志等级可在 `base.cfg.lua` 中设置；暂不支持通过环境变量覆盖。
- 所有 shell 命令均通过 `posix` 库执行，确保输出被正确捕获，避免因命令失败导致脚本中断。

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件（如果存在）。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进 confman。请确保代码风格与现有代码一致，并补充相应的测试。
