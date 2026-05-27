# 音乐分享 - Music Share

一个 iOS App，可以在分享列表中将音乐链接跨平台转换。支持 9 个主流音乐平台。

## 功能

- **分享扩展**：在任何 App 中分享音乐链接 → 选择"音乐分享" → 自动展示其他平台的对应链接 → 点击图标跳转
- **主 App**：粘贴音乐链接 → 一键转换 → 展示所有平台链接
- **双向转换**：国际平台 ↔ 国内平台互通

## 支持平台

| 国际 | 国内 |
|------|------|
| Spotify | QQ音乐 |
| Apple Music | 网易云音乐 |
| YouTube | |
| YouTube Music | |
| Deezer | |
| Tidal | |
| Amazon Music | |

## 构建到手机上

### 前置条件

- macOS + Xcode 16+
- Apple ID（免费）或 Apple Developer 账号
- iPhone（iOS 17+）
- [Homebrew](https://brew.sh)（如重新生成项目）

### 步骤

**1. 克隆项目**

```bash
git clone https://github.com/jyq920203/music-share.git
cd music-share
```

**2. 打开项目**

```bash
open MusicShare.xcodeproj
```

如果修改了 `project.yml`，需要重新生成项目：

```bash
brew install xcodegen        # 首次需要安装
xcodegen generate --spec project.yml
open MusicShare.xcodeproj
```

**3. 配置签名**

在 Xcode 中：
- 点击左侧项目导航中的 **MusicShare**（蓝色图标）
- 选择 **Signing & Capabilities** 标签
- 勾选 **Automatically manage signing**
- **Team** 选择你的 Apple ID
- 两个 Target 都要配置：**MusicShare** 和 **ShareExtension**
- 如有 Bundle ID 冲突，改成你自己的（如 `com.yourname.musicshare.app`）

**4. 安装到手机**

- 用数据线连接 iPhone 到 Mac
- 在 Xcode 顶部工具栏，选择你的 iPhone（不是模拟器）
- 按 **Cmd+R** 运行
- 首次运行需要在 iPhone 上信任开发者证书：
  **设置 → 通用 → VPN 与设备管理 → 信任你的开发者证书**

**5. 使用分享扩展**

安装完成后，分享扩展需要手动启用：
- 在任意 App（如 Apple Music、QQ音乐）中点击分享
- 分享列表底部 → **编辑操作** → 找到"音乐分享" → 添加
- 之后就能在分享列表中直接使用了

## 技术架构

- **API**：[Song.link (Odesli)](https://odesli.co) 提供国际平台链接转换
- **国内平台**：直接调用 QQ音乐 / 网易云音乐搜索 API
- **UI**：SwiftUI
- **项目管理**：[XcodeGen](https://github.com/yonaskolb/XcodeGen)

## License

MIT
