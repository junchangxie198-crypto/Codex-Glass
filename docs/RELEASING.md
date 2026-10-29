# 发布到 GitHub

1. 以本项目目录建立仓库并上传源码。`.gitignore` 排除运行数据和 `runtime/node.exe`。
2. 检查 `package.json` 中版本、`CHANGELOG.md` 以及 `clear-template.js` 的材质版本。
3. 本地执行 `scripts/test-package.ps1`，再执行 `scripts/package-release.ps1`。
4. 在 GitHub 创建对应版本的 Release，上传 `dist` 内的 ZIP 和 `.sha256` 文件，说明用户应下载 ZIP 并双击 `Start.cmd`。

也可推送对应版本标签，由 `.github/workflows/release.yml` 自动完成构建并上传 Release。手动触发工作流只生成 Actions 制品，不发布 Release。仓库需要允许工作流在标签构建中写入 Releases。

不要把个人截图或用过的壁纸作为发布素材。发行脚本通过 `release-files.json` 白名单选取文件，即使本目录曾经运行过，也不会携带控制状态、壁纸历史或连接端口。

修改打包范围时同步更新 `release-files.json`。Node 版本、SHA-256 和许可固定在 `runtime/node-provenance.json`；升级时必须同时更新官方校验值和完整许可文本。打包脚本会拒绝哈希不匹配的运行环境。

源码 ZIP 不包含 Node；给普通用户提供的 `Codex-Glass-v*-win-x64.zip` 则包含经校验的运行环境。不要将源码 ZIP 描述为免依赖安装包。

## 已验证范围

当前工作区执行过源码测试、PowerShell 5.1 语法检查、WPF 资源加载、官方 Codex 包检测，以及 ZIP 解压后首次初始化和再次运行验证。跨电脑体验、不同 Windows 缩放比例和未来 Codex 版本需要维护者继续验证。
