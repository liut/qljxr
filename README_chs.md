# QLJPEGXR — JPEG XR QuickLook Preview for macOS

macOS QuickLook 预览扩展，支持 **JPEG XR**（.jxr/.wdp/.hdp）图片，含 **HDR** 浮点格式（scRGB 32-bit float / 16-bit half）的色调映射预览。

## 功能

- 空格预览 .jxr 文件（QuickLook）
- 独立 App 查看器，支持打开、拖放、Cmd+O
- SDR 图片直通解码
- HDR float 格式自动检测并色调映射为 sRGB
- 显示基本信息：分辨率、色彩格式（SDR / HDR float）、文件大小
- 窗口自适应图片尺寸

## 构建

```bash
# 需要 Xcode 26+（macOS 26 SDK）

make          # Release 构建
make run      # 构建并启动 App
make deploy   # 构建、部署到 /Applications/、注册 QuickLook 扩展
```

要求 `DEVELOPMENT_TEAM` 已在 Xcode 中配置（项目使用 Automatic Code Signing）。

## 使用

**App 查看器：**

```bash
make run                         # 打开空白窗口，通过 File → Open 选文件
open -a QLJPEGXR image.jxr       # 直接打开指定文件
```

**QuickLook 预览：**

在 Finder 中选中 .jxr 文件，按空格键预览。

或命令行：

```bash
qlmanage -p image.jxr
```

## 项目结构

```
HostApp/                    # SwiftUI App（独立查看器）
JXRPreviewExtension/        # QuickLook 预览扩展
Shared/                     # App 与扩展共用的解码 & 渲染逻辑
  JXRDecoder.swift          # SDR/HDR 解码 + 色调映射
  CGImage+PixelBuffer.swift # CGImage / NSImage 创建
jxrlib/                     # jxrlib C 源码 + 桥接
  jxr_bridge.c/h            # SDR / HDR float 解码桥接函数
```

## HDR 色调映射

HDR 图片使用**亮度归一化**策略：

- 亮度 L ≤ 1（SDR 范围）：不做处理，保留原始色彩
- 亮度 L > 1（HDR 高光）：所有通道除以 L，保持 R:G:B 比例，亮度压缩到 ≤1

最后通过 sRGB gamma LUT 编码输出。

## 许可

MIT

## 致谢

- [4creators/jxrlib](https://github.com/4creators/jxrlib) — JPEG XR 解码库
- [SpecialKO/SKIV](https://github.com/SpecialKO/SKIV) — Windows HDR 图片查看器（参考实现）
