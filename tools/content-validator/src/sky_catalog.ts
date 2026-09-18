/**
 * TS 侧的天空目录上界。所有者是 `game/src/shared/sky_catalog.gd`；本常量是它的
 * 镜像，由 `gdscript_sync.ts` 机械钉住（写法照 `CANONICAL_MAX_DEPTH`）。
 *
 * 为什么校验器要查目录、而 `SimulationBundle.from_dictionary` 不查：本工具是
 * **发布前**门禁，与 `TraprushTopologyCompiler` 同侧——认不出的天空不该被发布
 * 出去。解码器故意宽松，因为已发布内容必须按它发布时的形状裁决（ADR-0006
 * §1.4），天空是纯表现，认不出回退默认天空，不该让一局开不起来。三级门禁表见
 * `sky_catalog.gd` 文件头。
 */
export const SKY_ID_MAX = 1;
