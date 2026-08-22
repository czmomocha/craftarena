# CD-91 决策记录

> 文档 ID：CD-91
> 单一事实源：每项决策的选择来源、覆盖关系与延期标记
> 加载建议：只在需要追溯"某个设计为什么是这样"或确认某项是否真的拍板过时读取。日常实现不需要
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第二十六条
> 相关：[CD-63 开发期决策清单](../60-plan/63-open-decisions.md)、[CD-62 风险登记册](../60-plan/62-risk-register.md)
> 派生自：初稿 v0.2 附录 D

## 使用与追加规则

本文件记录选择来源，防止 AI 把推荐项误当决定。

- 若正文与本文件冲突，以**时间较新的明确决策**为准；
- `延期` 表示**不得推断默认值**；
- 出现新拍板或推翻旧决策时，必须在对应小节追加一行，并注明被覆盖的旧值；
- 只记录"选了什么"和"覆盖了什么"，具体规则写进所有者文档。

---

## D.1 产品、平台与账号

- `project_name = craft_arena`（2026-08-20）：正式定名 **Craft Arena／工坊竞技场**，GitHub 仓库名 `craftarena`。此前无正式名称，文档中仅以工作目录名 `AIGame` 临时指代，该临时称呼作废。命名规范见 [CD-11 §1](../10-product/11-scope-and-platforms.md)。
- `primary_validation_path = hybrid_web_gate`：桌面原生开发，测试者优先 Web，共享功能持续过 Web 门禁。
- `web_editor_scope = light_editor`：Web 游玩 + 轻量编辑；完整规则图留在桌面。
- `authoring_identity`：允许匿名编辑，云端自动保存并保留本地缓存。
- `guest_draft_lifecycle = guest_30_claim`：Guest ID + 恢复密钥，云端 30 天，登录后认领。
- `product_packaging = one_platform_modular`：同品牌、账号、大厅，双玩法按需资源模块。
- `module_delivery_boundary = assets_content_only`：可信代码随基础包，模块只下发资源与内容。
- `minimum_device_tier = midrange_2020`；`fps_targets = pc60_mobile30`。
- `browser_support = chromium_desktop`：桌面 Chrome/Edge 最新两个大版本。
- `web_offline = native_only`：安装版离线；Web 在线但保留本地草稿。
- `mobile_editor_scope = play_only`；`pc_input_support = keyboard_only`。
- `localization_scope = zh_en`；`accessibility_baseline = defer_accessibility`。
- `art_direction = stylized_lowpoly`；`target_age = teen_plus`。
- `monetization_phase1 = none_no_hooks`。
- `client_signing = platform_minimum`；`steam_integration_timing = after_core_adapter`。

## D.2 UGC、发现与发布

- `ugc_visibility = automatic_public`；仅指长期测试环境。
- `ugc_asset_scope = platform_assets_only`。
- `publication_safety = technical_only`：只做技术、结构和预算验证。
- `public_text_scope = no_free_text`：系统名/词库 + 结构化标签。
- `ugc_playability_label = publish_with_status`：机器人未完成仍公开并标记。
- `ugc_feedback = ratings`；`ugc_rating_dimensions = overall_plus_tags`。
- `ugc_sorting = simple_tabs`：最新、评分、游玩次数、已验证。
- `ugc_publish_rate = no_limits`；`ugc_feed_dedup = manual_cleanup`。
- `ugc_validation_concurrency = one_concurrent_queue`。
- `ugc_validation_time = tiered_validation`：60 秒快检 + 10 分钟后台抽样。
- `draft_autosave = command_log_checkpoints`。
- `collaborative_editing = single_editor_fork`：单写者；他人可只读或复制私有草稿；设备租约互斥。
- `ugc_forking = never_allowed`。
- `ugc_withdrawal = hard_delete`；`hard_delete_audit_exception = minimal_tombstone`。
- `asset_versioning = latest_alias`，后由 `asset_latest_gameplay_boundary = visual_latest_gameplay_immutable` 限定：仅视觉/音效自动 latest。
- `ugc_data_format = json_source_binary_bundle`。
- `schema_compatibility = current_plus_two`。
- `rule_vm_compatibility = versioned_semantics`。
- `creator_rule_access = templates_web_graph_desktop`。
- `dual_editor_architecture = shared_framework_mode_tools`。

## D.3 TRAPRUSH

- `traprush_camera = isometric_soft_follow`。
- `traprush_movement = single_jump_autostep`。
- `traprush_player_collision`：实体碰撞、阻挡推挤，道具/工具可眩晕。
- `traprush_combat_intensity = nonlethal_control`。
- `traprush_anti_block = no_protection`。
- `traprush_chokepoint_rule = hard_choke_allowed`。
- `traprush_stalemate = baseline_shove`。
- `traprush_item_distribution = fixed_seeded_spawns`。
- `traprush_destructible_scope = shared_world`。
- `traprush_failure_penalty = unlimited_respawn`。
- `traprush_match_duration = creator_defined`；`traprush_time_bounds`：内容级不设上限。
- `match_server_lease = renewable_lease`。
- `traprush_finish_requirement`：默认终点，创作者可组合自定义结束条件。
- `custom_end_validation = typed_bounded_terminal`。
- `traprush_player_count`：在线 1～8 人，单人也走服务器。
- `traprush_web_player_count = same_eight`。
- `player_collision_prediction = predict_remote_capsules`。
- `authoritative_character_physics = custom_kinematic`。
- `traprush_offline_opponents = local_ghost`。
- `authoritative_motion_dof = upright_3d_kinematic`。
- `traprush_inventory = 延期`。

## D.4 BASTION

- `bastion_player_count = one_and_two`：官方先 1v1，再开放 2v2。
- `bastion_team_building = personal_sector_gold`。
- `bastion_obstacle_draft = simultaneous_hidden`。
- `bastion_obstacle_ownership = captain_places`。
- `bastion_captain_selection = volunteer_vote_fallback`。
- `bastion_path_blocking = path_always_required`。
- `bastion_tower_placement = slot_based`。
- `bastion_tower_control = fully_automatic`。
- `bastion_offense_model = shared_waves_score`。
- `bastion_win_condition = core_first_or_score`。
- `bastion_wave_symmetry = identical_seeded`。
- `bastion_economy = base_plus_kill_capped`。
- `bastion_obstacle_destruction = mixed_by_archetype`。
- `bastion_build_timing = creator_defined`。
- `bastion_build_policy_authoring = whitelisted_policies`。
- `bastion_wave_count = creator_unbounded`。
- `bastion_balance_authoring = bounded_multipliers`。
- `bastion_asymmetric_teams = creator_defined_teams`。
- `bastion_max_players = max_eight`。
- `asymmetric_compensation = platform_presets`。
- `bastion_pathfinding = waypoint_graph`。
- `tower_target_priority = player_selects_whitelist`。
- `bastion_offline_opponent = template_bot`。
- `hidden_state_sync = 延期`。

## D.5 热修改、Preview 与内容版本

- `ugc_version_activation = all_next_safe_tick`，后由补丁等级决策限定。
- `live_match_patch_level = p0_p1_only`：P2/P3 只用于新对局。
- `live_p1_safe_point = phase_boundary_notify`。
- `live_patch_rollout = all_immediately`。
- `live_patch_rollback = technical_auto_rollback`。
- `edit_play_workflow = separate_preview_window`。
- `preview_patch_mode = persistent_incremental`。
- `multiplayer_preview_editing = author_live_patch`。

## D.6 AI、协作与项目治理

- `ai_autonomy = edit_test_no_commit_release` 已被 `ai_autonomy_scope = isolated_branch_commit_ok`（2026-08-21）**收窄解释、并未推翻**：禁止的是向 `main` 或受保护分支提交/推送，以及部署、发布与线上回滚；允许在隔离的 agent 分支或 worktree 上 commit/push。人类门禁落在 PR 合并（`pr_merge_gate`）与 GitHub 分支保护。**分支保护落地前仍按原字面执行**——Agent 不得创建任何提交。口径见 [CD-52 §1.1](../50-engineering/52-ai-workflow.md)，来源 [ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md)。
- `human_review_granularity = task_and_gate`。
- `ai_parallelism = lead_isolated_domains`。
- `multi_agent_runtime = cursor_native_worktree`（2026-08-21）：一期用 Cursor 原生 `/worktree` + `.cursor/agents/` + `.cursor/hooks.json`。不引入 Multica 类平台，不用 Cursor Automations。启用判据、并行度上限与角色表见 [CD-52 §5](../50-engineering/52-ai-workflow.md)。
- `code_review_assist = bugbot`（2026-08-21）：审查角色不建 Cursor subagent，由 Bugbot 承担。本地 `/review-bugbot` 先行，第一个 PR 走通后再开 PR 侧。不启用 fail-on-unresolved-issues，故不是 CI 门禁。配置与边界见 [CD-52 §5.2](../50-engineering/52-ai-workflow.md)，状态见 [CD-53 §4.1](../50-engineering/53-testing-and-ci.md)。该句被 `bugbot_agents_md = local_injected_pr_rules_exclude`（2026-08-21）补充：本地 `/review-bugbot` 子会话注入了完整 `AGENTS.md`（`always_applied_workspace_rules`）。GitHub PR Bugbot 官方规则源不含 `AGENTS.md`。该句再被 `bugbot_md = gate2_and_cd00_links`（2026-08-21）覆盖：`.cursor/BUGBOT.md` 已入库。PR 侧仍未开。该句再被 `bugbot_pr_side = deferred_ci_human`（2026-08-21）覆盖：GitHub PR 侧 Bugbot 因 SCM 安装对不上而跳过；合入靠 CI + 人类批准。本地 `/review-bugbot` 仍可用。
- `test_first_scope = core_tdd_presentation_after`。
- `ai_asset_policy = auto_publish_if_technical`。
- `ai_asset_sources = no_traceability`。
- `ai_asset_takedown = manual_case_review`。
- `repository_hosting = github_private`。
- `git_workflow = trunk_short_pr`。
- `ci_environment = github_plus_selfhosted`。
- `pr_merge_gate = required_ci_one_human`。
- `web_preview_frequency = per_pr_preview`。
- `preview_access = public_preview`。
- `preview_backend_isolation = ephemeral_sandbox`。
- `project_tracking = github_projects_adrs`。
- `engineering_language = chinese_docs_english_code`。
- `commit_convention = conventional_commits`。
- `dependency_updates = locked_scheduled`。
- `roadmap_style = milestone_no_dates`。
- `human_team_size = solo_owner`。
- `project_scaffold = minimal_custom`。
- `repo_structure = monorepo`。
- `asset_source_control = lfs_sources_and_runtime`。
- `godot_mcp_choice = 延期专项调研` 已被 `godot_mcp_choice = defer_to_m2`（2026-08-20）覆盖：专项调研完成后曾采纳 [ADR-0003](../../docs/adr/0003-godot-mcp-selection.md) 选项 A。该值再被 `godot_mcp_choice = godot_ai_v3_1_5`（2026-08-21）覆盖：M1 启动前第二轮调研选定 **Godot AI**（MIT，GDScript 插件 + Python/uv，~43 工具 / 120+ 操作）为唯一主 MCP。匿名遥测强制关；插件不入库；接入烟测与 M1 仿真拆开，M2 启动前生产级启用。版本与开关见 [CD-51 §7](../50-engineering/51-dev-environment.md)。
- `godot_version_lock = 4_7_2_stable`（2026-08-20）：精确锁定 Godot 4.7.2-stable Standard，覆盖原先只写到次版本的 "Godot 4.7 stable"。4.7-stable 首发于 2026-06-18，4.7.2 为官方推荐的兼容维护版；两台开发机与 CI 必须使用同一精确版本与配套导出模板。
- `human_playtest_cadence = internal_only`。
- `internal_acceptance = owner_signoff_checklist`。
- `milestone_m0 = exited`（2026-08-20）：[CD-61](../60-plan/61-milestones.md) M0 验收通过并退出。依据是 Linux CI 跑绿、人类按 [环境烟测清单](../../docs/runbooks/environment-smoke-test.md) 复跑全绿，以及编辑器 GUI 独立确认 Compatibility 与 17 个输入动作。下一阶段为 M1，**尚未启动**。该句被 `milestone_m1 = phase_a_started`（2026-08-21）覆盖：M1 阶段 A 启动；L0 信封（ID / 命令 / 事件 / 状态哈希）开工；定点运算仍待 [ADR-0005](../../docs/adr/0005-fixed-point-numeric-model.md) 拍板。Windows Godot AI 接入烟测第 7 步剩余两项（Vision Routing 关、无第二套 Godot MCP）同日由人类确认。该句再被 `milestone_m1 = phase_a_a1_a4`（2026-08-21）覆盖：定点已拍板并合入；[CD-52 §5.1](../50-engineering/52-ai-workflow.md) 的 A1 与 A4 成立（[PR #1](https://github.com/czmomocha/craftarena/pull/1)）；A2 / A3 未成立，并行仍禁止。
- `pr_loop_a4 = first_pr_merged`（2026-08-21）：走通「Agent 产出 → PR → CI 全绿 → 人类 review → 人类合并」。证据：[PR #1](https://github.com/czmomocha/craftarena/pull/1)。不因此开启多域并行。
- `redline_scan = constitution_subset`（2026-08-21）：[ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) §4.2 门禁 2 落入 `tools/redline-scanner/` 与 CI step `npm run redline-scan`。覆盖第五条 SceneTree/`float`、第七条 `.gdextension` 与 `.cs`、第十一条 Godot 3 高信号子集。不因此把 A3 报全绿。
- `codeowners_file = four_contract_paths`（2026-08-21）：`.github/CODEOWNERS` 覆盖 `game/src/shared/`、`backend/contracts/`、`Confirmed-docs/`、`.github/`，所有者 `@czmomocha`。GitHub `require_code_owner_reviews` 仍关，不把 A2 报全绿。该句被 `branch_protection = pr_ci_codeowners`（2026-08-21）覆盖：人类已保存 `main` 保护；API 确认 code owner 审查、两个 CI status check，以及要求与 `main` 同步。A2 成立。`enforce_admins` 仍关。A3 的 worktree 仍缺，并行仍禁止。该句再被 `worktree_setup = cursor_json_and_loadenv`（2026-08-21）覆盖：`.cursor/worktrees.json` + DevLauncher `loadEnvFile` 落地；A1–A4 成立。阶段 B 未启动，不开启多域并行。hooks 仍缺。该句再被 `shell_guard_hook = fail_closed_git`（2026-08-21）覆盖：`.cursor/hooks.json` `beforeShellExecution` + `failClosed: true`；判定逻辑在 `tools/shell-guard/`。拦向 `main` 的提交/推送与 `git worktree remove --force`。阶段 B 仍未启动。该句再被 `bugbot_agents_md = local_injected_pr_rules_exclude`（2026-08-21）覆盖：本地 `/review-bugbot` 已跑且注入了 `AGENTS.md`；PR 侧官方规则源仍不含 `AGENTS.md`。`.cursor/BUGBOT.md` 仍未建，PR 侧 Bugbot 仍未开，不开启多域并行。该句再被 `cursor_agents = six_roles_no_reviewer`（2026-08-21）覆盖：`.cursor/agents/` 六份角色定义入库，无审查 Agent。仍不开启多域并行。该句再被 `bugbot_md = gate2_and_cd00_links`（2026-08-21）覆盖：`.cursor/BUGBOT.md` 入库，只写门禁 2 机械红线并链接 CD-00 / `AGENTS.md`。该句再被 `bugbot_pr_side = deferred_ci_human`（2026-08-21）覆盖：跳过 GitHub PR 侧 Bugbot；合入靠 CI + 人类批准。多域并行不再等 PR Bugbot。该句再被 `two_domain_round1 = sim_world_and_traprush_gates`（2026-08-21）覆盖：待办 14 第一轮已合入（[PR #13](https://github.com/czmomocha/craftarena/pull/13) 检查点/传送、[PR #14](https://github.com/czmomocha/craftarena/pull/14) SimulationWorld 骨架）；人类确认审查节奏可继续两域。第 3 域未开。该句再被 `two_domain_round2 = xz_block_and_move_intents`（2026-08-21）覆盖：待办 14 第二轮已合入（[PR #16](https://github.com/czmomocha/craftarena/pull/16) XZ 目的地阻挡、[PR #17](https://github.com/czmomocha/craftarena/pull/17) MoveIntent/重置落点/推击冷却）；第 3 域未开。该句再被 `two_domain_round3 = y_move_and_jump_shove`（2026-08-21）覆盖：待办 14 第三轮已合入（[PR #19](https://github.com/czmomocha/craftarena/pull/19) Jump/Shove 解码、[PR #20](https://github.com/czmomocha/craftarena/pull/20) Y 轴目的地阻挡）；第 3 域未开。该句再被 `two_domain_round4 = intent_step_and_static_box`（2026-08-22）覆盖：待办 14 第四轮已合入（[PR #22](https://github.com/czmomocha/craftarena/pull/22) 意图驱动仿真、[PR #23](https://github.com/czmomocha/craftarena/pull/23) 静态盒阻挡）；第 3 域未开。该句再被 `two_domain_round5 = destructible_and_sweep`（2026-08-22）覆盖：待办 14 第五轮已合入（[PR #25](https://github.com/czmomocha/craftarena/pull/25) 可破坏耐久、[PR #26](https://github.com/czmomocha/craftarena/pull/26) 位移扫掠）；第 3 域未开。该句再被 `two_domain_round6 = shove_apply_and_try_set_pose`（2026-08-22）覆盖：待办 14 第六轮已合入（[PR #28](https://github.com/czmomocha/craftarena/pull/28) 推击应用、[PR #29](https://github.com/czmomocha/craftarena/pull/29) 占用感知落地）；第 3 域未开。该句再被 `two_domain_round7 = portal_land_and_box_solid`（2026-08-22）覆盖：待办 14 第七轮已合入（[PR #31](https://github.com/czmomocha/craftarena/pull/31) 传送落地等待、[PR #32](https://github.com/czmomocha/craftarena/pull/32) 关闭静态盒阻挡）；第 3 域未开。该句再被 `two_domain_round8 = box_overlap_and_graybox`（2026-08-22）覆盖：待办 14 第八轮已合入（[PR #34](https://github.com/czmomocha/craftarena/pull/34) 静态盒重叠查询、[PR #35](https://github.com/czmomocha/craftarena/pull/35) 单人灰盒跑道夹具）；第 3 域未开。该句再被 `two_domain_round9 = replay_tape_and_pad_accept`（2026-08-22）覆盖：待办 14 第九轮已合入（[PR #37](https://github.com/czmomocha/craftarena/pull/37) 命令回放带、[PR #38](https://github.com/czmomocha/craftarena/pull/38) 占用检查点垫）；第 3 域未开。该句再被 `two_domain_round10 = snapshot_ring_and_graybox_pads`（2026-08-22）覆盖：待办 14 第十轮已合入（[PR #40](https://github.com/czmomocha/craftarena/pull/40) 周期关键快照环、[PR #41](https://github.com/czmomocha/craftarena/pull/41) 灰盒垫盒接线）；第 3 域未开。该句再被 `two_domain_chapter1 = occupancy_queries_and_graybox_replay`（2026-08-22）覆盖：细轮收尾 [PR #43](https://github.com/czmomocha/craftarena/pull/43) 重叠盒枚举、[PR #44](https://github.com/czmomocha/craftarena/pull/44) 灰盒命令磁带与首章 [PR #45](https://github.com/czmomocha/craftarena/pull/45) 胶囊占用查询、[PR #46](https://github.com/czmomocha/craftarena/pull/46) 灰盒快照与周期 hazard 已合入；阶段 B 改为章节节奏（每域更大功能 PR，文档章末补一次）；第 3 域未开。该句再被 `two_domain_chapter2 = pose_overlap_and_interact`（2026-08-22）覆盖：第二章已合入（[PR #48](https://github.com/czmomocha/craftarena/pull/48) 候选姿态占用查询、[PR #49](https://github.com/czmomocha/craftarena/pull/49) InteractIntent 灰盒伤害）；第 3 域未开。该句再被 `two_domain_chapter3 = solid_occupancy_and_use_item`（2026-08-22）覆盖：第三章已合入（[PR #51](https://github.com/czmomocha/craftarena/pull/51) UseItemIntent 爆破 stub、[PR #52](https://github.com/czmomocha/craftarena/pull/52) 仅 solid 占用查询）；第 3 域未开。该句再被 `two_domain_chapter4 = support_probe_and_finish_pad`（2026-08-22）覆盖：第四章已合入（[PR #54](https://github.com/czmomocha/craftarena/pull/54) 固体支撑探测、[PR #55](https://github.com/czmomocha/craftarena/pull/55) 灰盒终点垫）；第 3 域未开。该句再被 `two_domain_chapter5 = y_contact_and_grounded_jump`（2026-08-22）覆盖：第五章已合入（[PR #57](https://github.com/czmomocha/craftarena/pull/57) Y 轴直到阻挡、[PR #58](https://github.com/czmomocha/craftarena/pull/58) 接地跳跃）；第 3 域未开。该句再被 `two_domain_chapter6 = xz_contact_and_apply_fall`（2026-08-22）覆盖：第六章已合入（[PR #60](https://github.com/czmomocha/craftarena/pull/60) 调用方下落、[PR #61](https://github.com/czmomocha/craftarena/pull/61) XZ 直到阻挡）；第 3 域未开。该句再被 `two_domain_chapter7 = range_query_and_commit_fall`（2026-08-22）覆盖：第七章已合入（[PR #63](https://github.com/czmomocha/craftarena/pull/63) tick 内下落、[PR #64](https://github.com/czmomocha/craftarena/pull/64) 掉出范围查询）；第 3 域未开。该句再被 `two_domain_chapter8 = volume_block_and_move_contact`（2026-08-22）覆盖：[PR #66](https://github.com/czmomocha/craftarena/pull/66) 无 id 体积占用、[PR #67](https://github.com/czmomocha/craftarena/pull/67) MoveIntent 水平接触已合入；第 3 域未开。该句再被 `two_domain_arc_a = jump_shove_contact_and_range_reset`（2026-08-22）覆盖：阶段 B 改为按弧开 PR；弧 A 为 Jump/Shove 直到阻挡与掉出范围复位（[PR #68](https://github.com/czmomocha/craftarena/pull/68)）；无独立仿真切片时允许单域；第 3 域未开。该句再被 `two_domain_arc_b = graybox_full_run_replay`（2026-08-22）覆盖：弧 B 为单人灰盒整段可回放（[PR #69](https://github.com/czmomocha/craftarena/pull/69)）；无独立仿真切片，单域；第 3 域未开。该句再被 `two_domain_arc_c = graybox_tape_replay`（2026-08-22）覆盖：弧 C 为 PLAYER 磁带回放进灰盒（[PR #70](https://github.com/czmomocha/craftarena/pull/70)）；无独立仿真切片，单域；第 3 域未开。该句再被 `two_domain_arc_d = graybox_system_occupancy_log`（2026-08-22）覆盖：弧 D 为 SYSTEM 占用日志进灰盒（[PR #71](https://github.com/czmomocha/craftarena/pull/71)）；无独立仿真切片，单域；第 3 域未开。
- `macos_second_machine_smoke = verified`（2026-08-20）：覆盖原先「macOS 命令列尚未在真机验证」。人类按 CD-51 §4.1 在 macOS 26.5.2 arm64 跑通十步与编辑器 GUI；固定命令见 [README.md](../../README.md)，签字记录见烟测清单第 10 步。顺带确认 `--check-only` 在 macOS 上类型错误仍打印但退出码为 0，与 Windows 的退出码 1 不同。

## D.7 后端、数据与部署

- `match_server_runtime = godot_headless_shared`。
- `control_plane_stack = typescript_fastify`。
- `primary_database = postgresql` 已被后续 `postgres_deployment = sqlite_control_plane` 覆盖：一期 SQLite，PostgreSQL 为迁移目标。
- `sqlite_ownership = control_plane_only`。
- `primary_region = hong_kong`；`cloud_provider = tencent_cloud_hk`，其中托管 PostgreSQL 部分被 SQLite 决策覆盖。
- `phase1_ccu = ccu_50`；`capacity_overflow = fifo_queue`。
- `match_process_model = one_process_per_match`。
- `match_orchestration = match_host_supervisor`。
- `realtime_gateway = single_gateway_proxy`。
- `gateway_service_boundary = separate_ts_service`。
- `deployment_environments = local_staging_only`：本地 + 长期测试环境，无正式 Production。
- `monthly_infra_budget`：具体月度上限未锁定；已知已有腾讯云香港服务器和域名，一期无邮件服务。
- `phase1_auth = email_magic_link` 已被 `auth_without_email = username_password_now` 覆盖。
- `password_recovery = no_recovery`。
- `test_registration = open_registration`。
- `registration_abuse_control = no_protection`。
- `public_player_names = free_username_public`。
- `in_game_communication = none`。
- `secrets_management = plain_env_repo` 后由 `plain_secret_scope = disposable_dev_only` 限定：只允许可销毁沙盒假凭据入库。
- `data_retention = balanced_retention`。
- `telemetry_policy = pseudonymous_optout`。
- `match_history_ui = backend_only`。
- `backup_policy = no_backup`。
- `production_monitoring = logs_only`。

## D.8 网络、仿真与测试

- `network_serialization = json_control_binary_match`。
- `realtime_transport = websocket_all_first`。
- `simulation_numeric_model = fixed_point_core`。该值被 `fixed_point_contract = q48_16_trunc_reject_lut4096`（2026-08-21）具体化：[ADR-0005](../../docs/adr/0005-fixed-point-numeric-model.md) 选项 1。空间 `SCALE = 65536`；经济/伤害尺度 1；向零截断；溢出拒绝 + 64×64→128；BAM + 4096 整数 LUT + 整数插值。数字只在 [CD-42 §1.1](../40-technical/42-contracts-and-rulevm.md) 维护。
- `authoritative_collision_shapes = primitive_compound`。
- `gdscript_typing = strict_core_typed_ui_flexible`。
- `rule_vm_execution = versioned_bytecode_interpreter`。
- `api_contract = json_schema_openapi`。L0 信封 JSON Schema 已于 2026-08-21 落入 `backend/contracts/schemas/`，由 `tools/content-validator/` 做正反例；未引入 Ajv。Component Schema / OpenAPI 仍未落地，本键不被覆盖。
- `network_targets = region_real_data`。
- `provisional_network_gate = no_gate`。
- `network_correctness_tests = manual_network_tests`。
- `manual_network_cadence = ad_hoc`。
- `performance_regression = optimize_when_bad`。
- `client_anticheat = server_validation_only`。
- `cheat_enforcement = log_only`。
- `bot_fill = no_bot_fill`。

## D.9 明确延期或跳过

- `bug_reporting` 及 Bug 提交、客服、通知、告警展示等同类问题：跳过，后续开发再决定。
- 道具栏、具体数值、时长、动画、精确频率等实现级玩法细节：统一延期。定点数尺度已迁出，见 D.8 `fixed_point_contract`。
- `hidden_state_sync`：延期，不默认采用任何推荐协议。

## D.10 文档体系

- `docs_structure = index_first_single_source`（2026-08-20）：将 2129 行一体化初稿拆分为 `Confirmed-docs/` 文档群；宪法常驻，其余按主题分章按需读取。原初稿退役为归档，不再作为依据。
