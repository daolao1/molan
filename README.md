# 墨澜 (Molan)

小说写作辅助应用 —— 管理小说的人物、地点、物品、场景设定,配置你自己的 LLM API 辅助创作。Flutter 构建,一套代码覆盖 Android / iOS / Windows / macOS / Linux。

## 功能

- **小说管理**:多本小说,书名与简介
- **设定管理**:每本小说下的人物 / 地点 / 物品 / 场景卡片
- **LLM 接入**:设置页配置兼容 OpenAI 格式的 Base URL / API Key / 模型

## 安装

从 [Releases](https://github.com/daolao1/molan/releases) 下载对应平台安装包。

### macOS 提示“已损坏”或被拦截？

安装包未经 Apple 公证（需付费开发者账号），下载后首次打开会被 Gatekeeper 拦截。解除方法，二选一：

```bash
# 方法一：移除隔离属性（路径按实际调整）
xattr -cr /Applications/molan.app
```

方法二：打开被拦后，去 **系统设置 → 隐私与安全性**，拉到底部点 **仍要打开**。

仅首次需要，之后正常使用。

## 开发

```bash
flutter pub get
flutter run -d macos   # 或 -d <其他设备>
```

发版：改 pubspec.yaml 的 version → commit → 打 `vX.Y.Z` tag 推送，CI 自动构建四端产物挂到 Releases。

## License

MIT
