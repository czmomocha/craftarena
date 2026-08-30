/**
 * CD-11 §8.1 单资产预算的机器可判定形式。
 *
 * **数值的所有者是 [CD-11 §8.1]，不是本文件。** 这里只是它的一份可执行副本，
 * 改数字必须先改那份文档（宪法第二十六条）。本文件刻意不导出"可配置的预算"：
 * 能被命令行参数放宽的准入线等于没有准入线。
 *
 * 拍板于 2026-08-30，来源 CD-91 D.1 `asset_budget_v1`。观察数据见
 * docs/plans/asset-bake-trial-2026-08.md（那是一次本机试验，不是预算）。
 */

/** 静态、无骨骼绑定的物件。 */
export const MAX_TRIANGLES_STATIC = 3_000;

/** 带动画绑定（glTF 有 skin）的角色。 */
export const MAX_TRIANGLES_RIGGED = 6_000;

/** 每张贴图的边长上限，两个方向都算。全用途同一档：baseColor / ORM / normal。 */
export const MAX_TEXTURE_SIZE = 512;

/** 单个资产文件体积。2 MB 按 1024 进制。 */
export const MAX_FILE_BYTES = 2 * 1024 * 1024;

/**
 * 为什么不卡编码格式（PNG / JPEG / KTX2）：它只影响磁盘，不影响显存。
 * 1024 的贴图无论存成 PNG 还是 JPEG，进引擎后都还是约 1 MB
 * （烘焙试验 §5.2 实测：GLB 降 57%，导入后的 .ctex 只降 16%）。
 * 真正要卡的是分辨率，所以本表只有 MAX_TEXTURE_SIZE。
 */

/** glTF primitive.mode：只有 TRIANGLES 能被可靠地数成三角面，见 countTriangles。 */
export const GLTF_MODE_TRIANGLES = 4;
export const GLTF_MODE_TRIANGLE_STRIP = 5;
export const GLTF_MODE_TRIANGLE_FAN = 6;
