# Ricochet Labyrinth

一个使用 Godot 4.7 制作的霓虹竖屏打砖块 / 迷宫弹球原型，玩法与视觉参考了 `preview.png`。

## 运行

用 Godot 4.7+ 打开本目录，直接运行主场景即可。

```powershell
godot --path . 
```

## 操作

- 鼠标 / 触屏左右拖动：移动挡板
- `A` / `D` 或方向键：移动挡板
- 鼠标左键 / 触屏点击 / `Space` / `Enter`：发射球
- `R`：重新开始
- 球漏出底部会损失一颗球；底部计数是当前球数，`LOST` 是累计丢失数

## 已实现内容

- 程序化迷宫砖块关卡，共 13 行彩色砖块
- 多球机制：连击达到阈值时自动分裂新球
- 砖块掉落道具：用挡板接住后立即生效
  - `MULTI`：当前场上所有小球翻倍（上限 24 颗）
  - `SPEED`：当前所有小球速度提升 18%（上限 980）
  - 默认 14% 掉落率；连续 8 次未掉落时必定掉落，两种道具交替出现
- 连击倍率、动态清除百分比、波次切换
- `FIRE RUSH`：命中积累能量，满能量后进入 6 秒火焰冲刺
  - 球变成火焰球并可穿透摧毁砖块
  - 火焰粒子、余烬、橙色屏幕氛围
  - 冲刺持续时间与能量条同步显示
- 墙面/砖块/挡板的全自定义圆形与 AABB 碰撞
- 霓虹光晕、拖尾、撞击粒子、屏幕震动、漂浮数字
- 程序化合成音效，不依赖任何外部图片、字体或音频素材

## 代码入口

- `main.tscn`：主场景
- `scripts/main.gd`：全部玩法、碰撞、程序化绘制、UI 与音效逻辑

几个方便继续调整的位置：

- 场地与挡板尺寸：`SCREEN_*`、`FIELD_*`、`PADDLE_*` 常量
- 关卡密度：`BRICK_ROWS`、`BRICK_COLS`
- 迷宫障碍：`create_walls()`
- 难度与速度：`launch_ball()`、`collide_paddle()`
- 火焰冲刺时长 / 充能速度：`start_fire_rush()`、`destroy_brick()`
- 道具掉落率 / 上限：`POWERUP_DROP_CHANCE`、`POWERUP_MAX_BALLS`
- 道具效果：`apply_multiball_powerup()`、`apply_speed_powerup()`

## 测试

```powershell
godot --headless --path . --script res://tests/powerup_test.gd
```

测试会验证道具拾取、1 → 2 → 4 多球翻倍、速度提升，以及两类道具的掉落顺序。

## 预览

![gameplay preview](preview.png)

![powerup preview](powerup_preview.png)

