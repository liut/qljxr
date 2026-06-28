---
date: 2026-06-28
topic: jxr-quicklook
---

# JPEG XR QuickLook 预览扩展

## Summary

一个 macOS QuickLook 预览扩展，让用户在 Finder 中按空格键即可预览 .jxr 图片。基于 jxrlib C 解码库（源码嵌入），SwiftUI 构建预览界面，打包为可拖拽安装的宿主 App。

---

## Problem Frame

JPEG XR（.jxr）是 Microsoft 开发的静态图像压缩格式，ITU-T 标准（T.832）。在 Windows 上通过 WIC 原生支持，但 macOS 没有内置解码能力。团队中处理 .jxr 文件的成员目前无法在 Finder 中预览文件内容，只能通过专门的图像软件打开，效率低且打断工作流。

参考实现 4creators/jxrlib 提供了完整的 C 语言编解码器，解码路径成熟稳定，可作为预览扩展的解码后端。

---

## Key Flows

- F1. 空格键预览
  - **Trigger:** 用户在 Finder 中选中一个 .jxr 文件，按下空格键
  - **Actors:** 团队成员
  - **Steps:** QuickLook 系统加载扩展 → 扩展读取文件数据 → jxrlib 解码为像素 → SwiftUI 渲染预览
  - **Outcome:** 预览窗口显示图片内容，支持标准缩放和窗口调整
  - **Covered by:** R1, R2, R3

- F2. 预览画廊（多文件）
  - **Trigger:** 用户在 Finder 中选中多个 .jxr 文件，按下空格键
  - **Actors:** 团队成员
  - **Steps:** QuickLook 系统加载扩展 → 显示第一个文件的预览 → 用户可通过箭头键或点击切换文件 → 每个文件独立解码渲染
  - **Outcome:** 用户可在预览窗口中浏览所有选中图片
  - **Covered by:** R4

---

## Requirements

**预览核心**

- R1. 扩展注册 .jxr 文件类型，macOS 识别并调起预览
- R2. 解码 .jxr 文件为 RGB 位图，正确渲染图片内容
- R3. 支持标准预览窗口交互：缩放（双指捏合 / 快捷键）、拖拽移动已放大的图片

**多文件**

- R4. 支持多文件预览：选中多个 .jxr 文件时，可在预览窗口中前后切换

**异常处理**

- R5. 文件不是有效的 JPEG XR 格式时，预览窗口显示明确的错误提示而非崩溃
- R6. 图片尺寸极大（如超过 10000px 边长）时，预览仍可正常显示而不导致内存问题

---

## Acceptance Examples

- AE1. **Covers R1, R2.** Given Finder 中有一个有效的 `photo.jxr` 文件，when 用户选中并按空格键，预览窗口弹出并显示图片内容。
- AE2. **Covers R4.** Given Finder 中有三个 .jxr 文件被同时选中，when 用户按空格键，预览窗口显示第一张图片，用户按右箭头键可切换到第二张、第三张。
- AE3. **Covers R5.** Given Finder 中有一个被损坏的 `broken.jxr`（内容不是有效 JPEG XR 数据），when 用户按空格键，预览窗口显示「无法预览」或类似的错误提示，扩展不崩溃。
- AE4. **Covers R6.** Given 一个尺寸为 15000×10000 像素的有效 .jxr 文件，when 用户按空格键，预览窗口显示图片的适配缩放视图，系统响应正常。

---

## Success Criteria

- 团队成员将 App 拖入 /Applications 后，Finder 空格键即可正常预览 .jxr 文件
- 预览体验与 macOS 原生支持的格式（PNG、JPEG）基本一致：打开快、缩放流畅、切换文件无卡顿
- 对损坏或非标准文件不崩溃，给出可理解的反馈

---

## Scope Boundaries

- 不支持缩略图（Finder 图标预览）
- 不支持 .hdp / .wdp（旧版 HD Photo 格式）
- 不包含 JPEG XR 编码能力
- 不提供图像编辑、转换、导出功能

---

## Key Decisions

- C 源码直接嵌入而非预编译库：简化构建流程，团队 clone 即可编译，避免库路径配置问题
- 仅解码不编码：预览扩展只需读取能力，编码/转换不在范围内
- 仅 .jxr 格式：聚焦标准格式，旧版 HD Photo 格式（.hdp/.wdp）使用率低，如有需求后续添加

---

## Dependencies / Assumptions

- 依赖 4creators/jxrlib 的解码模块（image/decode），需验证其在 macOS ARM64 上可编译
- 假设 jxrlib 的 C 代码不需要修改即可在 Apple Clang 下编译
- 假设团队成员的 Mac 运行 macOS 13（Ventura）或更高版本（SwiftUI QuickLook 预览扩展的系统要求）

---

## Outstanding Questions

### Deferred to Planning

- [Affects R2][Technical] jxrlib 解码模块（image/decode）在 Apple Silicon 上的编译兼容性验证
- [Affects R2][Technical] 解码后位图到 NSImage / CGImage 的转换路径选择
- [Technical] 宿主 App 的形态：最小菜单栏 App vs 自动化安装脚本
- [Technical] 扩展的代码签名策略（团队分发是否需要 Developer ID）
