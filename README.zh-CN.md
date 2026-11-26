# Kindle Watch Page Turner

[English](README.md)

用 Apple Watch 快捷指令或辅助触控的手指手势，给 **Kindle 原生阅读器**翻页。
接收端向前台阅读窗口发送 X11 PageDown／PageUp 按下和松开事件，**不写入触摸设备**，
也不要求进入 KOReader 看书。KOReader 在这里只提供已有的 LuaJIT／LuaSocket 运行库。

版本 **0.2.1**；许可证 **GPL-3.0-or-later**。

## 验证范围

本地测试设备为已越狱的 KPW5（Paperwhite 11 代），固件记录为 5.16.2.1.1，
已有 KOReader v2023.10；手表为 Series 11，用户报告 watchOS 27.2。

已验证电脑请求、手表多次手势翻页、Kindle 休眠再唤醒，以及两小时阅读模式的启动。
用户确认页面实际翻动且屏幕正常；前后只读检查中 Xorg 进程保持一致。
**没有完成整整两小时的耐久测试，也没有验证其他设备／固件组合。**

早期本地触摸注入原型曾与 Xorg 崩溃、持续白屏同时发生，已停用且不包含在仓库中。
这里的实现不会回退到触摸、evdev 或 uinput 注入。这不是 Amazon 或 Apple 官方配件。

## 安装前提

- Kindle 已越狱，装有 KUAL。
- `/mnt/us/koreader` 已有兼容的 KOReader LuaJIT／LuaSocket 运行库。
- 原生阅读界面使用 `com.lab126.booklet.reader` 的 X11 窗口。
- 系统有 `timeout`、`lipc-get-prop`、`iptables`。
- Kindle 与手机／手表的网络路径可以在局域网互通。手机热点不是必须，普通路由器也可以；
  校园网或访客 Wi-Fi 的客户端隔离可能阻止互通。

日常阅读不需要电脑一直运行。本扩展不安装内核模块，不改固件、键盘映射、焦点或开机服务。

## 安装

1. 下载项目，在电脑生成本机专用配置：

   ```sh
   python3 scripts/setup_config.py --host 192.168.1.50
   ```

   示例地址替换为 Kindle 的 IP。脚本生成的 `config.lua` 和 `shortcut-urls.txt`
   都被 Git 忽略；令牌不会打印到终端。

2. 将 `extension/kindle-watch-keys` 整个文件夹复制到 Kindle 的 `extensions` 目录。
3. 安全弹出 Kindle，在 KUAL 中选择：
   **Watch Keys v2 → Start reading (2 hours)**。
4. 回到平时的原生阅读器，打开书籍。

更新时保留设备上原有的 `config.lua`，这样现有快捷指令中的令牌不用改。
需要历史日志时，也保留 `runtime/`。不要使用他人的私有配置。

## 设置快捷指令和手表

1. 在 iPhone“快捷指令”中新建「Kindle 下一页」。
2. 添加“获取 URL 内容（Get Contents of URL）”，把本地 `shortcut-urls.txt`
   中的 Next 完整网址填入**该动作自己的 URL 字段**，方法选 GET。
3. 在 iPhone 手动运行一次，允许所需的局域网访问，并确认 Kindle 实际翻页。
4. 在快捷指令详细信息中打开“在 Apple Watch 上显示”，然后在手表上手动运行确认。
5. 打开 Watch App：**Accessibility → AssistiveTouch → Hand Gestures**，
   把 **Double Tap → Siri Shortcut → Kindle 下一页**。
6. 若希望亮屏后直接使用手势，可在提供此选项的系统中将 **Activation Gesture → None**。
   抬腕唤醒手表，再让食指和拇指互点两次。

这里用的是辅助触控中的 Double Tap，不是系统独立的原生 Double Tap 设置。
在已测试的手表配置中，辅助触控与原生 Wrist Flick（轻翻手腕）互斥，扩展不会解除这个限制。
参考 [Apple 辅助触控说明](https://support.apple.com/zh-cn/111111)。

上一页快捷指令使用 `/prev` 网址。

## 日常使用

- 每次在 KUAL 开启阅读模式后，可使用两小时，到期再次开启即可。
- Kindle 重启后需要手动开启；没有开机自启。
- `Stop v2` 可提前结束；程序退出时清理本次添加的临时端口规则。
- Kindle 需处于清醒状态且前台是正文阅读界面；其他情况拒绝该次请求。
- 两次翻页至少间隔 1.5 秒。
- Kindle IP 改变后，需要更新快捷指令里的网址。
- 日常模式不需要电脑逐次放行测试额度。

令牌通过局域网 HTTP 传输，请保留在自己的设备中，不要把接收端口映射到互联网。
仓库不包含实际令牌、设备日志、个人书籍信息或已签名的私有快捷指令。

## 排查与测试

`Start diagnostics (15 min)` 是独立的只读起始诊断模式，需要额外开放一次或五次额度才能翻页。
详见 [接口与保护机制](docs/architecture.md)。电脑客户端需要 Python 3 和 curl 7.76 或更新版本：

```sh
python3 scripts/remote_client.py 192.168.1.50 health
python3 scripts/remote_client.py 192.168.1.50 probe
```

Mac 的 VPN 干扰本地路由时，可以为单次客户端命令加上 `--interface en0`，不修改系统路由。

HTTP 成功只表示 X11 处理了请求，仍需看屏幕确认实际翻页。
图形接口异常或 Xorg 进程改变时，本次会话会停用后续翻页。
若持续白屏，停止触发并保留 `runtime/server.log`、`runtime/launcher.log`；
可按 [Amazon 的说明](https://digprjsurvey.amazon.com/csad/help/node/G9WDGDTCSDQMSU7Z)
持续按住电源键 40 秒后松开来重启冻结设备。首页搜索 `;dm` 可导出系统日志，
但日志可能包含个人数据，不要直接公开上传。

运行离线测试：

```sh
python3 -m pip install -r requirements-dev.txt
python3 tests/test_kindle_keys.py
sh -n extension/kindle-watch-keys/control.sh extension/kindle-watch-keys/run.sh
```

测试覆盖协议报文、目标窗口过滤、只读探测、错误无重试、额度、阅读模式到期、频率限制、
休眠／前台变化拒绝、图形故障锁定。网络及 HTTP 测试使用模拟接口，不会控制实际设备。

## 来源

X11 实现改写自 zampierilucas 及贡献者的
[kindle-button-mapper-rs/src/xkey.rs](https://github.com/zampierilucas/kindle-button-mapper-rs/blob/master/src/xkey.rs)。
见 [NOTICE](NOTICE) 和 [LICENSE](LICENSE)。
