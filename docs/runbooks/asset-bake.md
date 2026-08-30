# 资产烘焙与预算（runbook）

生成工具（TRELLIS、混元 3D 等）的产物贴图通常是 4096，单文件动辄几十 MB，**过不了 [CD-11 §8.1](../../Confirmed-docs/10-product/11-scope-and-platforms.md) 的准入线**。本文是把它压到预算内、再确认它真的合格的两条命令。

- 预算数值的所有者是 **CD-11 §8.1**，本文不复述，只调用；
- 观察数据见 [烘焙试验记录](../plans/asset-bake-trial-2026-08.md)（一次本机试验，不是规范）；
- 烘焙是**入库前的一次性预处理**。入库物是烘焙后的 `.glb`，不是脚本的输出流水线。

---

## 1. 校验：`npm run asset-budget`

```bash
npm run asset-budget                 # 扫 game/ 下所有 .glb
npm run asset-budget path/to/a.glb   # 只查指定文件（可以在仓库外）
```

超预算退出码 1，并逐项说出原因（哪张贴图、多大、超了什么）。这条命令**已进 CI**（`backend` job 的 Single-asset budget step），所以超限资产进不了 `main`。

它判四件事：

| 判定 | 依据 |
|---|---|
| 三角面 | 有 glTF `skin` 就按角色档，否则静态档。**看 skin 不看文件名** |
| 贴图边长 | 每张贴图的长边，从图像 header 读，**不解码像素** |
| 文件体积 | 磁盘字节 |
| 能不能判定 | 认不出的贴图格式、非三角 primitive、LFS 指针一律**拒绝而不是放过** |

零 native 依赖（只 `@gltf-transform/core`），所以 `sharp` 装不上的机器仍有门禁。

## 2. 烘焙：`npx @gltf-transform/cli`

```bash
npx --yes @gltf-transform/cli@4.4.2 resize in.glb out.glb --width 512 --height 512
npm run asset-budget out.glb
```

实测（本机 macOS arm64，2026-08-30）：混元 3D 产物 **29.74 MB → 803 KB，约 7 秒**，几何逐字不变（3000 面），三张 4096 贴图全部降到 512。

### 为什么烘焙工具不进 package.json

`@gltf-transform/cli` 拖 **205 个包**，其中 `sharp@~0.34.5` 挂着 4 个 libvips CVE（`GHSA-f88m-g3jw-g9cj`），而上游 4.4.2 仍钉在那个区间；`npm audit fix --force` 会把 cli 降到 2.5.1，那是更坏的选择。

所以分两层：

- **校验**（门禁，每次 PR 跑）依赖 `@gltf-transform/core` —— 2 个包，`npm audit` 0 漏洞；
- **烘焙**（开发机，偶尔跑）用 `npx` 临时拉起，**版本写死 `@4.4.2`**，不进 lock。

代价与边界，别外推：

- 烘焙工具**不在 lock 里**，所以它的传递依赖不保证逐字节可复现。可接受，因为入库物是产物 `.glb`，且产物由第 1 节的门禁把关；
- CVE 仍然存在，只是不在本仓库的依赖树里。它的攻击面是"用 libvips 解码不可信图像"，而这里解码的是**你自己生成的资产**，在开发机上，不在服务端、不在玩家包、不在 CI；
- `npx` 首次运行要下载 205 个包（约十几秒）；离线机器跑不了烘焙，但**跑得了校验**；
- macOS 上会打印 `libvips-cpp` 两个版本冲突的 `objc[...]` 警告（`ndarray-pixels` 与 `sharp` 各带一份）。实测不影响结果，可以忽略。

### 换机器与 Windows

两条命令都是纯 Node，Windows / Linux 同样可用 —— 这正是引入它替掉旧脚本的原因：那份试验脚本硬编码 `/usr/bin/sips`，**只在 macOS 成立**，而且不入库。

## 3. 还没做的事

- **自动化烘焙流水线**（批量、CI 内烘焙、按用途分档的独立参数）**不在 C4**，人类 2026-08-30 明确。第 2 节是一条手动命令，不是流水线；
- 按用途分档（baseColor / ORM / normal 各自不同上限）没有实现。CD-11 §8.1 是全用途同一档 512，`resize` 也就一刀切。烘焙试验 §5.1、§5.3 记录了分档的收益与"ORM / normal 不能转 JPEG"的坑，等流水线立项时再用；
- KTX2 / Basis 未测（`--width/--height` 之外的压缩路径）；
- 场景总量、Draw call、材质数、骨骼上限**不判**，仍属 [CD-63 §1.7](../../Confirmed-docs/60-plan/63-open-decisions.md) 延期。
