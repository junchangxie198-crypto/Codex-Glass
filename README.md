# Codex Glass · Codex 玻璃美化

为 Windows 版 Codex 添加可开关的半透明磨砂外观。支持本地壁纸、最近五张图片快速切换、独立调节雾化与颜色深浅，以及跟随壁纸明暗的文字配色。

这是独立的社区外观工具，与 OpenAI 无隶属关系。不会修改 Codex 安装文件、账号、聊天内容或模型设置。

## 下载后使用

1. 在本仓库 **Releases** 下载 `Codex-Glass-v3.6.14-win-x64.zip`。请下载发行 ZIP；GitHub 自动生成的 `Source code` 不含运行环境。
2. 将 ZIP **完整解压**到你有写入权限的固定目录，例如“文档”中的 `Codex Glass`。不要直接在压缩包内运行。
3. 双击 **`Start.cmd`** 打开控制面板。发行 ZIP 已附带 Node.js，无需安装 Node、npm 包、Dream Skin 技能或 Wallpaper Skin。
4. 若 Codex 已普通启动且显示“接口未连接”，先自行退出 Codex，再点击控制面板中的 **“启动 Codex”**。控制器不会自动关闭你正在使用的窗口。
5. 点击 **“选择背景图片”**选择自己的 JPEG / PNG。包内不附带私人壁纸。

**环境：Windows 11 x64、已安装的官方 Windows 版 Codex。** 不支持 macOS、Linux、独立 ChatGPT 网页或第三方 Codex 客户端。界面选择器可能需要随 Codex 更新调整。

Windows 第一次运行未签名脚本可能显示来源提示，请先确认下载来源及 SHA-256。`Start.cmd` 只为本次启动指定 PowerShell 执行策略，不修改系统的全局策略，也不需要管理员权限。

## 功能与操作

| 控件 | 行为 |
| --- | --- |
| 开启 / 关闭美化 | 控制玻璃外观；关闭时恢复原生样式 |
| 启动 Codex | 激活官方应用并提供本机美化连接 |
| 连接状态 | 未连接时显示醒目的提示；已连接时显示绿色圆点 |
| 雾化模糊 | 0–20 px，默认 4 px；浮出侧栏为保证可读性保留独立的最低磨砂强度 |
| 颜色深浅 | 30%–95%，默认 64%；值越大遮罩越浓 |
| 背景图片 | 独立控制已选择壁纸的显示 |
| 选择图片 / 最近图片 | JPEG / PNG，最大 16 MB，宽高均不超过 10000 像素；保存最多五张历史副本 |
| 开机自启动 | 默认关闭，可由用户手动开启 |
| 点击关闭时 | 可选隐藏到托盘或退出控制器 |

控制面板和托盘菜单跟随 Windows 应用的浅色 / 深色设置。退出控制器后，当前玻璃效果保留至 Codex 窗口关闭；要立即还原，请先关闭美化和背景图片开关。

首次启动只打开控制面板，**不会同时启动 Codex 或 Wallpaper Skin**。可选双击 `Install Shortcuts.cmd` 创建桌面及开始菜单快捷方式。移动目录后请重新创建快捷方式；从新目录双击 `Start.cmd` 会自动更新本地运行路径。

## 数据与连接

配置、壁纸副本及最近图片记录只保存在解压目录。不会上传图片或读取账号凭据。后台连接只接受本机回环地址，并核验官方应用包身份、监听进程路径和连接会话；只注入 `app://-/index.html` 主页面，不进入网页、内嵌付费页或第三方站点内容。

图片和设置会写入以下位置，这些文件均在 `.gitignore` 中，且发行脚本采用文件白名单，永远不会把它们打入 ZIP：

```text
control-state.json         用户偏好
control-runtime.json       本机运行路径
control-live.json          当前连接状态
assets/user-wallpaper.jpg  当前壁纸副本（内容可能为 JPEG 或 PNG）
assets/recent-wallpapers/  最近图片副本
```

卸载时先关闭开机自启动并退出控制器，删除自行创建的快捷方式和解压目录即可。此操作不卸载 Codex。

## 从源码运行

安装 Node.js 22 或更新版本，然后在项目目录运行：

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\setup.ps1 -CheckOnly
.\Start.cmd
```

没有 npm 依赖，不需要 `npm install`。前端材质源码为 `clear-template.js`、`adaptive.css`、`clear-glass.css`；控制面板为 `control-window.xaml` 和 `controller.ps1`。

```powershell
node build.mjs
node --test control-tests.mjs wallpaper-state-tests.mjs wallpaper-payload-tests.mjs
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\test-package.ps1
```

## 上传 GitHub 与制作下载包

将**本文件所在目录**作为仓库根目录。使用 Git 上传源码，不要上传 `dist/`、`runtime/node.exe` 或运行产生的用户数据。无需上传本工作区其他文件夹。

```powershell
git init
git add .
git commit -m "Initial Codex Glass release"
# 按 GitHub 新仓库页面给出的命令添加远端并推送。
```

`runtime/node.exe` 被 Git 忽略，运行环境只随 Release ZIP 分发。若使用网页上传，请按 `release-files.json` 列出的文件上传，并保留 `.github` 中的工作流；不要直接拖入本地的整个 `runtime` 或 `dist` 文件夹。

本地生成可直接使用的下载包：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\package-release.ps1
```

结果位于 `dist/`：`*-win-x64.zip` 为附带运行环境的用户下载包，`*-source.zip` 为不含运行环境和个人数据的源码包，两个包都附 SHA-256 校验文件。上传仓库后，可把 ZIP 和校验文件添加到 GitHub Release 的 **Assets**，供用户下载。

仓库内已附 GitHub Actions：推送 `v3.6.14` 等版本标签会执行检查、下载并校验指定版本的官方 Node、生成 ZIP 并发布对应 Release；手动运行工作流只构建可下载的工作流制品。上传前请阅读 [发布说明](docs/RELEASING.md)。

## 许可

项目源码使用 [MIT License](LICENSE)。下载包中的 Node.js 及其依赖许可见 [runtime/LICENSE-node.txt](runtime/LICENSE-node.txt)；来源及校验值记录在 `runtime/node-provenance.json`。发行图标为本项目的玻璃图标，不分发从 Codex 安装包提取的官方图标。

详见 [第三方说明](THIRD_PARTY_NOTICES.md)及 [更新记录](CHANGELOG.md)。
