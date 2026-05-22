# 贡献指南 / Contributing

欢迎 Issue 和 Pull Request！

## 本地开发

整个工具就是一个 `index.html` 单文件 + 一个 macOS WKWebView 套壳。

**改前端**：直接编辑 `index.html`，用浏览器打开 `file://.../index.html` 刷新即可。所有依赖（html2canvas）已内联到 `<script>` 标签里，**没有任何构建步骤**。

**测试 macOS 套壳**：

```bash
cd build
./build.sh                    # 输出 dist/CodeReviewTool.app 和 .dmg
open ../dist/CodeReviewTool.app
```

需要 Xcode Command Line Tools（`xcode-select --install`）。脚本会自己处理通用二进制（arm64 + x86_64）、图标生成、ad-hoc 签名、DMG 打包。

## 发新版本

每次发版需要同步改 **三处**：

1. `build/build.sh` 第 9 行 `VERSION="x.y.z"`
2. `build/Info.plist` `CFBundleShortVersionString` 的 `<string>` 值
3. `build/Info.plist` `CFBundleVersion`（build number，递增整数）

然后：

```bash
git commit -am "Release vx.y.z"
git tag vx.y.z
git push origin main --tags
```

GitHub Actions 会自动跑 macOS runner、调用 `build.sh`、把 `.dmg` 和 `index.html` 一起上传到 Release。CI 会校验 tag 和文件里的版本号必须一致；不一致会直接失败、不会发出有问题的 release。

预发版命名 `vx.y.z-rc1` 之类，CI 会自动识别为 prerelease。

## 写代码的几条约定

- 不引入新的运行时依赖。任何外部库都必须能内联到 `index.html` 里（如 html2canvas），保持单文件、纯本地的承诺。
- 不联网。除了构建期之外，运行时不发起任何网络请求（包括字体、CDN、telemetry）。
- 不破坏 localStorage 的历史记录格式 —— 用户的历史对比在那里。如果数据结构必须改，写迁移函数（参考现有的 `normalizeState`）。
