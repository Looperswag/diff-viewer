# 贡献指南 / Contributing

欢迎 Issue 和 Pull Request！

## 本地开发

macOS 套壳（`build/`）不变；**前端 `index.html` 现在是从一个外部「dc」框架源工程导出的自包含打包文件**（内嵌全部字体 / 主题 / 导出库，约 15 MB），不是手写单文件。

**改前端**：在源工程里改 → 重新导出成一个 bundle → 跑补丁脚本生成 `index.html`：

```bash
python3 build/patch-bundle.py 你导出的bundle.html -o index.html
```

`patch-bundle.py` 会把每次导出都需要的 4 处修复**幂等**地加回去（重复跑是 no-op，脚本自带自检）：

1. **滚动修复** —— 框架把应用包了两层块级 `#dc-root` / `.sc-host`，截断了 `body` 的 flex 高度链，导致 `<main>` 无法下滑、`100vh` 以下的对比内容被 `body{overflow:hidden}` 裁掉；脚本注入 `display:contents` 把包裹层移出盒模型。
2. **删跟踪脚本** —— 移除导出时被注入的 `<script src="g.alicdn.com/…">`。
3. **删 preconnect** —— 去掉 Google Fonts 的 `<link rel="preconnect">`（字体本就内嵌成 blob），保证完全离线。
4. **解压资源** —— 解开 gzip 压缩的资源，使 loader 不再依赖 `DecompressionStream`（Safari 16.4+），老版 WebKit 也能跑。

> ⚠️ 跳过这一步，重新导出会**静默丢掉**这些修复 —— 页面又会无法下滑、又会带上外部脚本。所以「导出 → `patch-bundle.py` → 提交」是固定流程。

`index.html` 顶部那段 loader `<script>` 外壳可以手改；但应用本身的逻辑在内嵌的 blob 资源里，必须回源工程改。用浏览器打开 `file://.../index.html` 即可本地预览（完全离线）。

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
- 不联网。除了构建期之外，运行时不发起任何网络请求（包括字体、CDN、telemetry）—— `patch-bundle.py` 会兜底移除导出时混入的 alicdn 脚本和 Google Fonts preconnect。
- 不破坏 localStorage 的历史记录格式 —— 用户的历史对比在那里。如果数据结构必须改，写迁移函数（参考现有的 `normalizeState`）。
