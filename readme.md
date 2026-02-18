# vps_config

虽然觉得忘记的可能性不是很大，但是总归还是写一下

## 用法

初始化：

``` bash
./init.sh
```

## 约定

`*.cfg.lua`为confman自身的配置，`*.cfg.lua.exp`则为配置模版/示例，原则上应该直接`cp *.cfg.lua{.exp,}`然后修改以进行配置

每个文件夹中会存放对应服务的配置和安装脚本，大致组织方式类似`systemd`，*but in lua*

`module.exp`是示例服务配置，也可以用`cp`的方式新建一个服务配置

`src`作为保留名称，用于放置confman除入口点外的代码
