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

关卡布局保存在 `resources/levels/*.txt`，格式见 [levels.md](levels.md)。`GameWorld` 启动时用 `LevelLoader` 读取清单，运行时保存 `levels: Array[LevelDefinition]`、`level_index` 和 `loop_count`。

实体采用 `BallData`、`BrickData`、`PowerupData`，不再依赖字符串键字典。游戏状态使用 `GameWorld.State` 枚举。

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

完整格式、符号表和编关流程见 [levels.md](levels.md)。`LevelLoader` 会把 `X` / `=` 转成整格墙，把 `+` 按上下左右邻居拆成细墙段和连接段；`LevelGenerator` 只处理砖块符号。`GameWorld.build_level()` 每次从当前 `LevelDefinition` 生成砖块和墙；清关倒计时结束后 `next_level()` 推进 `level_index`，越过末尾时回到 `0` 并增加 `loop_count`。`wave` 是全局难度计数，持续增长并影响基础球速。

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

球按速度动态拆分子步，每步最多移动约 4.5 像素，依次处理外墙、丢球、挡板、迷宫墙和砖块。`CollisionGeometry.circle_rect_hit()` 返回 `CollisionHit` 或 `null`，包含法线和穿透深度。

世界通过 `drain_events()` 一次性交付事件。主要事件包括：

- `BALL_LAUNCHED` / `BALL_LOST` / `BALL_SPLIT`
- `WALL_HIT` / `OBSTACLE_HIT` / `PADDLE_HIT`
- `BRICK_DESTROYED` / `POWERUP_DROPPED` / `POWERUP_COLLECTED`
- `FIRE_STARTED` / `FIRE_ENDED`
- `LEVEL_CLEARED` / `LEVEL_STARTED` / `GAME_OVER` / `RUN_RESET`
- `MESSAGE` / `COMBO_POP`

新增表现时优先消费现有语义事件，避免让核心世界引用表现类。

## 6. 随机数与确定性

- `GameWorld.rng`：只服务关卡、发射、碰撞选择和道具。
- `GameEffects.rng`：粒子、漂浮和震动。
- `GameRenderer.visual_rng`：静态尘埃。
- `GameAudioManager.rng`：音高变化。

重开一局会重置玩法随机种子。渲染或音效消耗的随机数不会改变玩法序列。在相同初始状态、输入和物理步长下，核心模拟可复现。

## 7. 测试

- `tests/powerup_test.gd`：道具拾取、1 → 2 → 4 多球、速度提升、保底和掉落顺序。
- `tests/level_test.gd`：关卡清单、文本解析、符号配色、墙体与砖块生成。
- `tests/world_test.gd`：碰撞几何、固定输入确定性、火焰计时、关卡循环和开发者跳关。
- `tests/scene_smoke_test.gd`：主场景组合、模块创建和发射流程。
- `tests/powerup_preview.gd`：生成道具预览图。

修改核心规则时，应优先增加世界级测试；只有场景连接、输入或绘制相关问题才需要场景测试。

## 8. 后续扩展建议

- 新砖块：给 `BrickData` 增加明确类型和行为接口，不为每种砖块复制碰撞循环。
- 临时增益：在世界中增加独立的定时效果集合，由道具效果写入，HUD 只读取。
- 存档：序列化世界标量、实体和随机数状态，不保存 renderer、audio 或 HUD。
- 性能：当前实体规模无需对象池或空间分区；砖块和球数量显著增加后，再基于性能分析引入网格索引。
