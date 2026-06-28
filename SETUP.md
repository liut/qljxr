# JXR QuickLook — 项目设置

## 前置条件

- macOS 13 (Ventura) 或更高版本
- Xcode 15 或更高版本
- Apple Developer 账号（团队分发需要，个人测试可跳过）

## 第一步：创建 Xcode 项目

1. 打开 Xcode，选择 **File → New → Project**
2. 选择 **macOS → App**，点击 Next
3. 配置：
   - Product Name: `JXRQuickLook`
   - Team: 选择你的团队（个人测试选 None）
   - Language: **Swift**
   - Interface: **SwiftUI**
   - 取消勾选 "Include Tests"（后续可加）
4. 保存到 `qljxr/` 目录（与本 README 同级），**不要**创建新文件夹

## 第二步：添加 QuickLook 扩展 Target

1. **File → New → Target**
2. 搜索 "Quick Look"，选择 **Quick Look Preview Extension**
3. Product Name: `JXRPreviewExtension`
4. 确保 Team 与主 App 一致
5. 点击 Finish，提示激活 scheme 时选 **Activate**

## 第三步：配置扩展 Target 构建设置

选择 JXRPreviewExtension target → Build Settings：

1. **Objective-C Bridging Header**: 设为 `JXRPreviewExtension/JXR-Bridging-Header.h`
2. **Header Search Paths** 添加：
   - `$(SRCROOT)/jxrlib`
   - `$(SRCROOT)/jxrlib/common/include`
   - `$(SRCROOT)/jxrlib/image/sys`
   - `$(SRCROOT)/jxrlib/jxrgluelib`
3. **Preprocessor Macros** (在 Apple Clang - Preprocessing 下): 添加 `__ANSI__=1` 和 `DISABLE_PERF_MEASUREMENT=1`
4. 确认 **Deployment Target** 为 `macOS 13.0`

## 第四步：添加源文件到扩展 Target

在 Xcode 项目导航器中，将以下文件/文件夹**拖入**项目（确保勾选 JXRPreviewExtension target，不要勾选 HostApp target）：

### C 源码（全部加入 JXRPreviewExtension target 的 Compile Sources）
- `jxrlib/` 下所有 `.c` 和 `.h` 文件（约 30 个文件）
- 包括 `jxrlib/jxr_bridge.c` 和 `jxrlib/jxr_bridge.h`

### Swift 源码
- `JXRPreviewExtension/PreviewView.swift`
- `JXRPreviewExtension/PreviewViewController.swift`
- `JXRPreviewExtension/PreviewProvider.swift`
- `Shared/JXRDecoder.swift`
- `Shared/CGImage+PixelBuffer.swift`
- `Shared/UTType+JXR.swift`

以上 Swift 文件都加入 JXRPreviewExtension target。`UTType+JXR.swift` 同时加入两个 target。

### Host App Target
- `HostApp/HostApp.swift`（替换模板生成的文件）
- 删除模板生成的 `ContentView.swift`
- `Shared/UTType+JXR.swift`

## 第五步：替换 Info.plist

模板会生成默认的 Info.plist，替换为我们的：

- Host App: 用 `HostApp/Info.plist` 替换
- Extension: 用 `JXRPreviewExtension/Info.plist` 替换

修改两个 Info.plist 中的 `Bundle Identifier`：
- Host App: `com.yourcompany.JXRQuickLook`
- Extension: `com.yourcompany.JXRQuickLook.JXRPreviewExtension`

## 第六步：编译和测试

1. 选择 **Host App** scheme，目标为 **My Mac**
2. **Product → Build** (⌘B)
3. 编译成功后，**Product → Run** (⌘R) 启动 Host App（注册 UTI）
4. 退出 Host App
5. 在 Finder 中找到 .jxr 测试文件，按空格键查看预览

### 命令行验证
```bash
# 查看扩展是否被注册
qlmanage -m plugins | grep jxr

# 测试预览
qlmanage -p /path/to/test.jxr
```

## 代码签名

- **开发测试**: 使用 "Sign to Run Locally"（自动）
- **团队分发**: Archive → Distribute App → Development 或 Developer ID

团队分发需确保所有成员 Mac 上已安装并运行过 Host App（以注册 UTI 和扩展）。

## 故障排除

| 问题 | 解决方案 |
|------|---------|
| C 文件编译报错 `windows.h not found` | 确认 `__ANSI__=1` 已在 Preprocessor Macros 中设置 |
| `.jxr` 文件仍显示默认图标 | 确认已运行过 Host App（UTI 在 App 首次启动时注册） |
| QuickLook 显示"不支持的文件格式" | 运行 `qlmanage -d 4 -p test.jxr` 查看详细日志 |
| Extension 签名验证失败 | 确认 Host App 和 Extension 使用相同的 Team ID |
