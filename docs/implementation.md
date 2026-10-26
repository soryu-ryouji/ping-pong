# Ricochet Labyrinth 实现文档

Godot 4.7 单场景原型：霓虹竖屏打砖块 / 迷宫弹球。全部玩法、碰撞、绘制、UI、音效都在 `scripts/main.gd`（约 1100 行）中实现，无任何外部图片、字体、音频素材依赖。

- 主场景：`main.tscn`（仅一个挂 `main.gd` 的 `Node2D`）
- 分辨率：720 × 920，Mobile 渲染器，`canvas_items` 拉伸
- 测试：`tests/powerup_test.gd`（headless）、`tests/powerup_preview.gd`（截图生成预览图）

## 1. 整体架构

```
_ready()
 ├─ create_audio()    程序化合成 7 种音效 + 10 路 AudioStreamPlayer 轮播
 ├─ create_walls()    手工摆放 12 块迷宫障碍墙（Rect2 列表）
 ├─ create_dust()     95 个背景漂浮尘埃点
 ├─ create_ui()       11 个 Label（HUD + 状态提示）
 └─ reset_run()       重置全部状态 → build_level()

_process(delta) 每帧
 ├─ update_input / update_paddle   键盘 + 指针输入，挡板平滑跟随
 ├─ playing:  火焰计时 → 重生计时 → update_powerups → update_balls
 ├─ cleared:  倒计时到 0 自动 next_wave()
 ├─ update_effects / update_bricks / update_ui
 └─ queue_redraw()  → _draw() 全程序化绘制
```

没有使用 Godot 物理引擎，碰撞全部为手写几何（圆形 vs AABB），因此行为完全确定、可测试。

## 2. 核心数据结构

全部用 Dictionary/Array 表达，无自定义类：

| 数据 | 结构 |
|---|---|
| `balls[]` | `{pos, vel, radius, trail[], spin}` |
| `bricks[]` | `{rect, color, alive, flash}` |
| `walls[]` | `Rect2` 静态迷宫墙 |
| `powerups[]` | `{pos, vel, kind, color, age, phase}` |
| `particles[]` | `{pos, vel, life, max_life, color, size, gravity, drag}`（上限 760） |
| `floaters[]` | 漂浮文字 `{pos, text, color, size, life}`（上限 55） |

全局状态机：`state ∈ ready | playing | cleared | game_over`，另有 `wave / lives / combo / fire_energy / fire_time` 等标量。

随机数用固定种子 `rng.seed = 0x5EEDC0DE`，保证每次运行可复现（也方便测试断言）。

## 3. 输入与挡板

- `_unhandled_input` 统一处理：鼠标移动/点击、触屏 touch/drag、`A/D`、方向键（走 `ui_left/ui_right` 轴）、`Space/Enter` 发射、`R` 重开。
- 指针事件把 `paddle_target_x` 夹在场地内；键盘按 760 px/s 移动目标点。
- `update_paddle` 用指数平滑 `lerp(paddle_x, target, 1 - exp(-18Δt))` 追赶目标，同时记录 `paddle_velocity`（像素/秒），后续击球时把挡板速度的一部分传给球，增加操控感。

## 4. 球的物理与碰撞

### 4.1 子步进（防隧穿）

`step_ball` 按速度动态拆分子步：`substeps = clamp(ceil(speed·Δt / 4.5), 1, 14)`，每子步移动 → 依次检测外墙、挡板、迷宫墙、砖块。高速球也不会一帧穿过物体。

### 4.2 圆形 vs AABB：`circle_rect_hit`

核心碰撞函数，返回 `{normal, penetration}`：

1. 快速剔除：`rect.grow(r).has_point(center)` 不成立直接返回空。
2. 常规情况： clamp 出矩形上最近点，圆心减最近点得到法线和穿透深度。
3. 退化情况（圆心在矩形内部）：比较到四条边的距离，沿最近边推出，穿透量取 `边距 + r`。

调用方约定：只有 `vel.dot(normal) < 0`（确实朝面内运动）才反弹并做位置修正，避免一帧内重复反弹。

### 4.3 反弹规则

- **外墙**：三边反弹；底边 `y > FIELD_BOTTOM + 22` 判为丢球。
- **挡板** `collide_paddle`：按击球点相对挡板中心的位置 `rel ∈ [-1,1]` 映射出射角 `angle = rel × 1.02`（弧度），速度 `clamp(原速+7, 470, 880)`；叠加 `paddle_velocity × 0.1`（限 ±110）；强制保留至少 17% 的水平分量并按入射方向归一，防止“垂直上下死循环”。中心垂直回球时随机选边。
- **迷宫墙 / 砖块**：标准镜面反弹 `vel.bounce(normal)`。
- **防水平死锁**：每子步末若 `|vel.y| < 92`，在保持速率的前提下把竖直分量抬到 ±92，避免球卡进水平走廊无限横漂。

### 4.4 丢球与重生

单球丢失只移除该球并重置连击；**全部**球丢失才 `lives -= 1`，有命时 `respawn_timer = 1.15` 后回到 `ready`，否则 `game_over`。

## 5. 关卡生成 `build_level`

- 16 列 × 13 行网格（`BRICK_X/Y/STEP`），颜色按行在 HSV 色环 0.155→0.79 插值并加微小抖动。
- **雕刻开口**（硬编码规则）：特定行列挖洞形成迷宫感，再叠加 3.4% 随机挖洞。
- **墙冲突剔除**：砖块 rect 与任一 `walls.grow(3)` 相交则跳过。
- 后续波次预清除至多 8 块（`bricks.size()/4`），让 HUD 的清场百分比开局就有进展感。

## 6. 道具系统

### 6.1 掉落 `try_drop_powerup`

- 上限 `POWERUP_MAX_ACTIVE = 7`；基础掉率 14%，火焰冲刺期间降为 ×0.72。
- **保底（pity）**：`powerup_pity` 每次未掉落 +1，满 8 次必定掉落并清零。
- **种类交替**：按 `powerup_drop_counter` 奇偶在 `multiball` / `speed` 间交替，保证每局一定能体验到两种。

### 6.2 运动与拾取 `update_powerups`

- 重力加速（上限 235 px/s），水平速度指数阻尼；左右墙反弹衰减 0.72。
- 掉出底部 30px 消失；拾取判定区比绘制尺寸宽容（挡板上下 ±24/+18、横向 +14px）。

### 6.3 效果

- `MULTI`：复制当前所有球，每颗副本位置抖动 ±7px、速度旋转 ±0.38~0.72 rad、清空拖尾；上限 `POWERUP_MAX_BALLS = 24`。
- `SPEED`：所有球速率 ×1.18，封顶 980。

## 7. 连击、多球与 FIRE RUSH

- **连击**：每砖 +1（火焰期 +2）；每满 10 连显示倍率漂浮字。
- **连击多球**：`combo ≥ next_multiball_at`（初始 30，之后每档 +35）且球数 < 6 时 `launch_ball(true)`，即球数随连击自动增长，与道具多球并行。
- **能量**：普通命中 +3.4，火焰期命中直接把能量顶满 100；`fire_energy ≥ 100` 触发 `start_fire_rush()`。
- **FIRE RUSH**：持续 6 秒。期间 `collide_bricks` 不再反弹而是**穿透**连续摧毁（每子步扫一遍砖块）；球、拖尾、挡板、底部能量条全部切到金/橙配色；结束清空能量。
- 火焰计时在 `_process` 顶部独立递减，因此冲刺时长与 HUD 能量条完全同步。

## 8. 波次与胜负

- 砖块清零 → `clear_level()`：状态切 `cleared`，2.35 秒后 `next_wave()` 重建关卡（波次 +1，球速基础值 +18）。
- 命数耗尽 → `game_over`，点击/空格回到 `reset_run()`。

## 9. 特效系统

全部由 `update_effects` 推进、`_draw` 绘制：

- **粒子** `emit_burst` / `emit_ball_spark` / `emit_fire_ember_at`：寿命 + 重力 + 指数阻力，按 `life/max_life` 算透明度；超过 760 截断最旧。
- **拖尾**：每球保留最近 15 个位置，绘制三层线（宽色晕、主色、白色芯）+ 间隔圆点，无后处理也出霓虹感。
- **屏幕震动**：`shake` 衰减（22/s），绘制前对整个场景 `draw_set_transform` 随机偏移；命中事件按强度压入最大值。
- **闪光**：`flash_alpha` 衰减（1.9/s），全屏淡青色覆盖。
- **漂浮文字** `add_floater`：评分、WAVE、POWER DROP 等，匀速上飘渐隐。
- 砖块销毁时 `flash = 1` 在 `update_bricks` 中衰减，绘制时向白色插值。

## 10. 程序化音效 `synth_sound`

一个函数合成全部音效：22050 Hz、16-bit 单声道 WAV。波形 = 基频正弦 + 2.02×泛音×0.22 + 0.51×次谐波×0.18 + 13.4 kHz 高频噪声（比例可调），包络 `pow(1 - t, decay)`。7 种参数组合出命中/墙/挡板/丢球/火焰/清场/道具音色。10 路 `AudioStreamPlayer` 环形轮播避免音效互相打断，`pitch_scale` 随机 ±10% 防止重复感。

## 11. UI

- 11 个 `Label` 手工定位：`make_label` 统一字体大小、颜色、4px 深色描边；全部设 `MOUSE_FILTER_IGNORE` 不挡输入。
- `update_ui` 每帧刷新：波次、连击（带 `combo_pop` 缩放动画）、清场百分比、球数、丢失数、火焰能量/倒计时；`ready/game_over/cleared` 三态切换中央提示文字。
- 底部 `draw_bottom_meter` 画能量条：冲刺时显示剩余时间比例（橙），平时显示充能（金）。

## 12. 程序化绘制 `_draw`

绘制顺序即叠层顺序：渐变背景 + 尘埃 →（加震动偏移）外框/金属轨道 → 网格 → 砖块（光晕+剪影+三层填色+高光线）→ 迷宫墙 → 道具宝石（菱形 + 呼吸光圈 + MULTI/SPEED 图标与文字）→ 拖尾 → 粒子 → 挡板（圆头胶囊形 + 高光）→ 球 → 漂浮字 → 底部能量条 → 火焰氛围罩 → 非 playing 态暗色遮罩 → 全屏闪光。

所有“发光”都是多层低透明度几何叠加模拟，无 shader、无后处理。

## 13. 测试

`tests/powerup_test.gd` 以 `SceneTree` 脚本 headless 运行，直接实例化主场景、把 `state` 置为 `playing` 后调用内部函数断言：

1. 发射产生 1 球；
2. 在挡板位置投放 multiball 道具 → 被拾取且 1 → 2；
3. 再次翻倍 2 → 4；
4. speed 道具使球速严格增加；
5. 16 次 `try_drop_powerup` 后保底至少掉 2 个且种类按 multiball/speed 交替。

运行：

```powershell
godot --headless --path . --script res://tests/powerup_test.gd
```

`tests/powerup_preview.gd` 用于生成 `powerup_preview.png` 预览图。

## 14. 常用调参位置

| 需求 | 位置 |
|---|---|
| 场地/挡板尺寸 | `SCREEN_*`、`FIELD_*`、`PADDLE_*` 常量 |
| 关卡密度 | `BRICK_ROWS`、`BRICK_COLS` |
| 迷宫障碍 | `create_walls()` |
| 发射/击球难度 | `launch_ball()`、`collide_paddle()` |
| 冲刺时长/充能速度 | `start_fire_rush()`、`destroy_brick()` 中 `+3.4` |
| 掉率/球数上限 | `POWERUP_DROP_CHANCE`、`POWERUP_MAX_BALLS`、pity 阈值 `8` |
| 道具效果数值 | `apply_multiball_powerup()`、`apply_speed_powerup()` |
