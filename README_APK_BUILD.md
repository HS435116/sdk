# Android 4.4 及 Mediapad 10 Link+ 兼容性修复

已对项目进行以下修改，以解决 Android 4.4 (API 19) 上的 APK 解析失败问题，并确保与华为 Mediapad 10 Link+ 平板电脑的兼容性。

## 修改内容

### 1. AndroidManifest.xml
- 移除了 `<queries>` 元素（Android 4.4 不支持）。
- 添加了 `<supports-screens>` 元素，支持所有屏幕尺寸和密度，确保在平板设备上正确显示。

### 2. build.gradle.kts (app)
- 将 `minSdk` 设置为 19（Android 4.4）。
- 启用了 `multiDexEnabled = true`。
- 在签名配置中禁用了 V2/V3/V4 签名，仅启用 V1 签名（旧版签名）。
- 在 `packaging` 块中设置了 `isLegacyPackaging = true`。
- 配置了 `ndk.abiFilters` 以包含 `armeabi-v7a`、`arm64-v8a`、`x86`、`x86_64`。

### 3. 构建脚本
创建了两个批处理文件以简化构建和推送过程：
- `build_apk.bat` – 构建发布版 APK。
- `push_apk.bat` – 将 APK 推送到已连接的 Android 设备。

## 构建 APK

运行以下命令构建 APK：

```bash
flutter build apk --release
```

或者使用提供的脚本：

```bash
build_apk.bat
```

构建成功后，APK 将位于：
```
build\app\outputs\flutter-apk\app-release.apk
```

## 推送 APK 到设备

确保设备已通过 USB 连接并启用了 USB 调试。然后运行：

```bash
push_apk.bat
```

或者手动使用 adb：

```bash
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

## 验证安装

安装后，应用应能在 Android 4.4 设备和 Mediapad 10 Link+ 上正常运行。

## 注意事项

- 如果遇到任何解析错误，请检查设备存储空间和 Android 版本。
- 如需进一步调试，请使用 `adb logcat` 查看安装日志。

## 后续步骤

1. 运行 `build_apk.bat` 生成 APK。
2. 运行 `push_apk.bat` 安装到设备。
3. 测试应用功能。

如果问题仍然存在，请检查设备特定的兼容性问题，例如屏幕密度或 CPU 架构。
