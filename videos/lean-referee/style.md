# Style: 暗室里的校对台

- 背景 #0B0B0E；顶部一束很淡的暖色台灯光（径向渐变，透明度不超过 10%）；胶片颗粒（固定种子，幅度 ±4）；四周暗角
- 正文 #EDE6D6，强调金 #D4A84B，通过绿 #5FB37A，报错红 #D9534F。绿和红只用于 ✓ 和 error
- 字体：标题用思源宋体 SC Bold（Noto Serif CJK SC），正文用思源黑体 SC（Noto Sans CJK SC），代码用 JetBrains Mono，公式用 matplotlib mathtext（STIX）
- 章节标记：左上角写成 Lean 注释 `-- §1 质数`，JetBrains Mono 20px，金色，透明度 70%
- 主字幕放在底部安全区（y ≈ 600–660），居中；同时最多两行
- 揭示方式：遮罩从左向右擦出，或透明度淡入加 8px 上移，用 cubic ease-out，不用弹跳
- 辉光：只给"正在被检查的那一行"，半径 12px，强度 ≤ 0.5
- 不用：粒子爆炸、RGB 分离、镜头光晕、镜头抖动、弹跳缓动
- 示意性内容在右下角标注「示意」
