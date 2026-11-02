# 实现与扩展指南

## 1. 架构边界

项目采用单主场景和模块化代码，不引入 ECS、全局 EventBus 或第三方框架。

```text
PlayerInputController
        │ 修改输入目标 / 触发动作
        ▼
GameWorld.step(fixed_delta)
        │ 更新类型化模型，产生局部 GameEvent 队列
        ├──────────────┬──────────────┐
        ▼              ▼              ▼
GameRenderer       GameEffects   GameAudioManager
        │              │              │
        └──────────────┴──────────────┘
                       ▼
                    GameHUD
```

- `scripts/main.gd`：唯一组合根，创建模块、推进固定物理步、转发事件。
- `GameWorld`：状态机、计分、命数、多球、火焰冲刺、道具和关卡循环。
- `CollisionSystem`：子步进和碰撞响应；`CollisionGeometry` 是纯几何计算。
- `LevelLoader`：读取关卡清单和文本网格，解析成 `LevelDefinition`。
- `LevelGenerator`：从 `LevelDefinition` 生成砖块。
- `GameEvent`：玩法到表现层的局部事件，不使用全局单例。
- `presentation/`：只读取世界或消费事件，不修改玩法随机数。

`GameWorld` 是 `RefCounted`，核心测试不需要实例化主场景。主循环使用 `_physics_process`，避免渲染帧率改变碰撞更新步长。

## 2. 配置与内容

`resources/game_config.tres` 是默认配置，包含场地、挡板、速度、命数、连击、道具掉落和火焰冲刺数值，并引用：

- `level_manifest`：关卡顺序清单，默认 `res://resources/levels/levels.txt`。
- `powerups`：当前 `PowerupCatalog`。

与关卡布局相关的字段还有 `brick_area_margin`、`brick_area_max_height` 和 `brick_area_bottom`，分别控制 fit 模式的左右留白、砖块区最大高度，以及 fill 模式的底部边界。挡板成长由 `paddle_grow_per_hit` 控制，当前为每次 `+10px`；`GameWorld.paddle_max_width()` 取当前关卡 `brick_wall_width()`，所以挡板不会超过砖墙宽度。挡板的颜色升级按“基础宽度以上的增长量”计算，`paddle_flash` 驱动升级闪光；球掉落时 `_shrink_paddle_after_loss()` 会固定缩减 `paddle_shrink_per_loss`（默认 `20px`），不会低于基础宽度。

挡板移动由 `paddle_move_speed()` 控制：按当前扩展量在 `paddle_base_move_speed` 和 `paddle_min_move_speed` 之间插值，`update_paddle()` 用限速移动代替固定插值，所以变宽后更考验预判，缩回后速度恢复。经验曲线由 `xp_base_gain`、`xp_combo_scale`、`xp_required_base` 和 `xp_required_growth` 控制。`breakable_wall_hp` 和 `breakable_wall_min_speed` 控制 `+` 墙的耐久与速度门槛。

小球每次墙面、障碍或砖块反弹都会调用 `boost_ball_speed()`，增加 `bounce_speed_increment`，反弹加速受 `max_ball_speed = 1410`（初始速度的 3 倍）限制；如果球已经被 SPEED 道具推过上限，反弹不会把速度降回去。SPEED 道具本身不再设置上限，会持续按倍率加速。

关卡布局保存在 `resources/levels/*.txt`，格式见 [levels.md](levels.md)。`GameWorld` 启动时用 `LevelLoader` 读取清单，运行时保存 `levels: Array[LevelDefinition]`、`level_index` 和 `loop_count`。

实体采用 `BallData`、`BrickData`、`PowerupData`、`BreakableWallData`，不再依赖字符串键字典。`BrickData` 额外保存 `hp` / `max_hp` / `shake`；`BreakableWallData` 保存墙段矩形、HP、闪光和震动。挡板当前宽度由 `GameWorld.paddle_width` 维护，不再直接读取配置值。经验状态由 `GameWorld.xp`、`xp_level`、`xp_required` 和 `xp_flash` 维护。游戏状态使用 `GameWorld.State` 枚举。

## 3. 新增道具

### 第一步：实现效果

新建 `scripts/data/wide_paddle_powerup.gd`：

```gdscript
class_name WidePaddlePowerup
extends PowerupDefinition

@export var duration := 8.0

func apply(world: Variant, _pickup_position: Vector2) -> void:
    # 调用世界提供的规则接口；实际项目可在这里接入临时效果系统。
    var position := Vector2(world.paddle_x, world.config.paddle_y - 40.0)
    world.add_message(position, "WIDE PADDLE", color, 20, 1.0)
```

效果脚本通过 `PowerupDefinition.apply(world, pickup_position)` 扩展。已有 `MultiballPowerup` 和 `SpeedPowerup` 是完整示例。效果应修改玩法状态并发出语义事件，不直接操作 HUD、音频或绘制节点。

### 第二步：创建资源

在 `resources/powerups/` 新建 `.tres`，选择效果脚本并设置：

- `id`：稳定且唯一的 `StringName`。
- `display_name` / `short_name`：展示文本。
- `color` / `pickup_pitch`：默认表现参数。
- 自定义效果参数，例如速度倍率或持续时间。

### 第三步：注册

把资源加入 `resources/powerup_catalog.tres` 的 `definitions`。掉落按目录顺序轮换，因此无需修改 `GameWorld` 或 `collect_powerup()`。渲染器对未知道具提供通用宝石样式；需要专属图标时，再在 `GameRenderer.draw_powerups()` 增加绘制策略。

## 4. 新增或调整关卡

关卡是外部文本，不在 `.tres` 里配置：

1. 在 `resources/levels/` 新建 `.txt`，写 `name`、可选的格子参数和 `grid:` 网格。
2. 把文件名加入 `resources/levels/levels.txt`。
3. 运行 `tests/level_test.gd` 检查解析、砖块生成和墙体不重叠。

完整格式、符号表和编关流程见 [levels.md](levels.md)。`LevelLoader` 会先根据网格列数、砖块行数和 `GameConfig` 的可用区域做自动布局：默认 fit 模式按需统一缩放并水平居中；关卡写 `fill_field = true` 时改为按列数/总行数铺满可用区域；`auto_layout = false` 时保留手动 `origin` / `brick_size` / `step`。然后把 `X` / `=` 转成静态整格墙，把 `+` 按上下左右邻居拆成可破坏细墙段和连接段。`LevelGenerator` 只处理砖块符号：数字 `1`-`9` 默认 HP 等于数字，其他符号默认 1，`LevelDefinition.brick_hp` 可覆盖。

`GameWorld.build_level()` 每次从当前 `LevelDefinition` 生成砖块和墙；清关倒计时结束后 `next_level()` 推进 `level_index`，越过末尾时回到 `0` 并增加 `loop_count`。`wave` 是全局难度计数，持续增长并影响基础球速。

碰撞到多段耐久砖时，`CollisionSystem` 调用 `GameWorld.hit_brick()`。未击碎时砖块进入 `shake` 状态并发出 `BRICK_HIT`；击碎时才进入 `destroy_brick()`，结算 FIRE、道具和清除进度。FIRE RUSH 传入高伤害，直接击碎。

`+` 墙由 `BreakableWallData` 表示，`collide_breakable_walls()` 负责反弹和检测球速。只有球速达到 `breakable_wall_min_speed` 时，`hit_breakable_wall()` 才会扣除 1 点 HP；HP 归零后墙段消失。低速碰撞只反弹并轻微震动，不扣血。`remaining_bricks` 和 `remaining_breakable_walls` 同时归零才会触发 `clear_level()`，`clear_fraction` 也按两者总数计算。

`on_paddle_hit()` 增加接球 COMBO，并发出 `COMBO_POP` 让右上角数字弹跳/抖动；同时按当前 COMBO 调用 `add_xp()`。达到 `combo_first_life_reward` 和后续 `combo_life_reward_interval` 时，同样调用 `apply_level_up_reward()` 发放奖励，不再生成额外小球。满 XP 条后 `xp_required` 按 `xp_required_growth` 增长，发出 `XP_LEVEL_UP`，并调用 `apply_level_up_reward()`。当前 `GameConfig.level_up_reward` 指向 `ExtraLifeReward`，奖励 `+1 LIFE`；`UpgradeReward` 是可继承的资源接口，后续技能选择只需替换或传入选中的 reward。`double_balls()` 只由 MULTI 道具使用。破砖不增加 COMBO 或 XP。

若需要完全不同的生成算法，可以替换 `LevelGenerator`，或在 `LevelDefinition` 中增加字段，而不必修改碰撞或表现模块。

### 开发者跳关

`GameConfig.debug_tools` 打开时，`PlayerInputController` 会接管以下快捷键：

- `[` / `PageUp`：`GameWorld.previous_level_debug()`
- `]` / `PageDown`：`GameWorld.next_level_debug()`
- `1`-`9`：`GameWorld.jump_to_level(index)`
- `Shift+R`：`GameWorld.restart_level_debug()`

跳关统一走 `_begin_level()`：重建砖块和墙、清空球与道具、重置 FIRE/COMBO、回到 `READY`。`jump_to_level()` 按 `loop_count` 和关卡索引重新计算 `wave`，避免跳回低关时球速和 HUD 不一致。发布配置应将 `debug_tools` 关闭。

## 5. 模拟与事件

`GameWorld.step(delta)` 的顺序：

1. 更新挡板平滑运动。
2. `PLAYING` 下更新火焰计时、重生、道具和球。
3. `CLEARED` 下更新关卡切换倒计时。
4. 更新砖块闪光状态。

球按速度动态拆分子步，每步最多移动约 4.5 像素，依次处理外墙、丢球、挡板、迷宫墙和砖块。`CollisionGeometry.circle_rect_hit()` 返回 `CollisionHit` 或 `null`，包含法线和穿透深度。墙和砖块碰撞都会把球推出穿透区域（FIRE RUSH 穿透砖块时除外），避免球卡在实体内部；`update_balls()` 还跟踪每个球的位置变化，连续约 1.5 秒没有明显位移时会执行 `BALL RESCUE`，把球放回挡板上方并给一个向上初速度。

世界通过 `drain_events()` 一次性交付事件。主要事件包括：

- `BALL_LAUNCHED` / `BALL_LOST` / `BALL_SPLIT`
- `WALL_HIT` / `OBSTACLE_HIT` / `PADDLE_HIT`
- `BRICK_HIT` / `BRICK_DESTROYED` / `BREAKABLE_WALL_HIT` / `BREAKABLE_WALL_DESTROYED` / `POWERUP_DROPPED` / `POWERUP_COLLECTED`
- `BRICK_DESTROYED` 的 `event.size` 携带砖块最大耐久，供表现层放大彩色碎片粒子
- `FIRE_STARTED` / `FIRE_ENDED` / `XP_LEVEL_UP`
- `LEVEL_CLEARED` / `LEVEL_STARTED` / `GAME_OVER` / `RUN_RESET`
- `MESSAGE` / `COMBO_POP`

HUD 的 COMBO 字号由 `combo_font_size()` 按 `10 / 30 / 50 / 100 / 200 / 500` 阈值切换，COMBO 标签的位移和缩放由 `GameEffects.combo_pop` 驱动；底部 `LIVES` 会随升级奖励立即更新。

新增表现时优先消费现有语义事件，避免让核心世界引用表现类。

## 6. 随机数与确定性

- `GameWorld.rng`：只服务关卡、发射、碰撞选择和道具。
- `GameEffects.rng`：粒子、漂浮和震动。
- `GameRenderer.visual_rng`：静态尘埃。
- `GameAudioManager.rng`：音高变化。

重开一局会重置玩法随机种子。渲染或音效消耗的随机数不会改变玩法序列。在相同初始状态、输入和物理步长下，核心模拟可复现。

## 7. 测试

- `tests/powerup_test.gd`：道具拾取、1 → 2 → 4 多球、速度提升、保底和掉落顺序。
- `tests/level_test.gd`：关卡清单、文本解析、符号配色、多段耐久、自动布局、墙体与砖块生成。
- `tests/world_test.gd`：碰撞几何、固定输入确定性、火焰计时、关卡循环、开发者跳关、挡板成长/收缩与移动速度、反弹加速上限、可破坏墙、卡球救援、多段耐久砖、SPEED 无上限和经验升级奖励。
- `tests/scene_smoke_test.gd`：主场景组合、模块创建和发射流程。
- `tests/powerup_preview.gd`：生成道具预览图。

修改核心规则时，应优先增加世界级测试；只有场景连接、输入或绘制相关问题才需要场景测试。

## 8. 后续扩展建议

- 新砖块：给 `BrickData` 增加明确类型和行为接口，不为每种砖块复制碰撞循环。
- 临时增益：在世界中增加独立的定时效果集合，由道具效果写入，HUD 只读取。
- 存档：序列化世界标量、实体和随机数状态，不保存 renderer、audio 或 HUD。
- 性能：当前实体规模无需对象池或空间分区；砖块和球数量显著增加后，再基于性能分析引入网格索引。
