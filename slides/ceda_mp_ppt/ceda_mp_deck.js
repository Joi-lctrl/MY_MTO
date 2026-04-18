const path = require("path");
const PptxGenJS = require("pptxgenjs");
const {
  imageSizingContain,
} = require("./pptxgenjs_helpers/image");
const {
  warnIfSlideHasOverlaps,
  warnIfSlideElementsOutOfBounds,
} = require("./pptxgenjs_helpers/layout");

const pptx = new PptxGenJS();
pptx.layout = "LAYOUT_WIDE";
pptx.author = "OpenAI Codex";
pptx.company = "OpenAI";
pptx.subject = "CEDA_MP presentation";
pptx.title = "CEDA_MP 内容解读";
pptx.lang = "zh-CN";
pptx.theme = {
  headFontFace: "Microsoft YaHei",
  bodyFontFace: "Microsoft YaHei",
  lang: "zh-CN",
};

const W = 13.333;
const H = 7.5;
const COLORS = {
  ink: "153243",
  teal: "0E7490",
  sky: "DFF6FF",
  mint: "D9F99D",
  sand: "FFF7D6",
  coral: "FFDDD2",
  red: "C2410C",
  line: "A3B8C8",
  navy: "0F172A",
  slate: "475569",
  white: "FFFFFF",
  pale: "F8FBFD",
};

function addBackdrop(slide, accent = COLORS.sky) {
  slide.background = { color: COLORS.pale };
  slide.addShape(pptx.ShapeType.rect, {
    x: 0,
    y: 0,
    w: 13.333,
    h: 0.22,
    line: { color: accent, transparency: 100 },
    fill: { color: accent },
  });
}

function addTitle(slide, kicker, title, subtitle) {
  slide.addText(kicker, {
    x: 0.75,
    y: 0.48,
    w: 4.8,
    h: 0.25,
    fontFace: "Georgia",
    fontSize: 11,
    bold: true,
    color: COLORS.teal,
    charSpace: 1.5,
  });
  slide.addText(title, {
    x: 0.75,
    y: 0.78,
    w: 7.8,
    h: 0.6,
    fontSize: 25,
    bold: true,
    color: COLORS.navy,
  });
  slide.addText(subtitle, {
    x: 0.75,
    y: 1.42,
    w: 8.8,
    h: 0.35,
    fontSize: 10.5,
    color: COLORS.slate,
  });
}

function addFooter(slide, page) {
  slide.addText(`CEDA_MP | MToP | ${page}`, {
    x: 11.55,
    y: 7.05,
    w: 1.1,
    h: 0.18,
    align: "right",
    fontSize: 8,
    color: "7C8B9A",
  });
}

function addBulletList(slide, items, box, color = COLORS.ink, fontSize = 15) {
  const runs = [];
  items.forEach((item) => {
    runs.push({
      text: item,
      options: {
        bullet: { indent: 14 },
        hanging: 2,
        breakLine: true,
      },
    });
  });
  slide.addText(runs, {
    ...box,
    fontSize,
    color,
    breakLine: false,
    margin: 0,
    valign: "top",
    paraSpaceAfterPt: 12,
    fit: "shrink",
  });
}

function addPill(slide, text, x, y, w, fill, color = COLORS.navy) {
  slide.addShape(pptx.ShapeType.roundRect, {
    x,
    y,
    w,
    h: 0.35,
    rectRadius: 0.08,
    line: { color: fill, transparency: 100 },
    fill: { color: fill },
  });
  slide.addText(text, {
    x: x + 0.08,
    y: y + 0.06,
    w: w - 0.16,
    h: 0.2,
    fontSize: 10,
    bold: true,
    color,
    align: "center",
  });
}

function addCard(slide, cfg) {
  slide.addShape(pptx.ShapeType.roundRect, {
    x: cfg.x,
    y: cfg.y,
    w: cfg.w,
    h: cfg.h,
    rectRadius: 0.06,
    line: { color: cfg.line || COLORS.line, width: 1.1 },
    fill: { color: cfg.fill || COLORS.white },
  });
  if (cfg.label) {
    addPill(slide, cfg.label, cfg.x + 0.18, cfg.y + 0.14, cfg.labelWidth || 1.3, cfg.labelFill || COLORS.sky);
  }
  slide.addText(cfg.title, {
    x: cfg.x + 0.2,
    y: cfg.y + 0.56,
    w: cfg.w - 0.4,
    h: 0.32,
    fontSize: 15.5,
    bold: true,
    color: COLORS.navy,
  });
  if (cfg.body) {
    slide.addText(cfg.body, {
      x: cfg.x + 0.2,
      y: cfg.y + 0.92,
      w: cfg.w - 0.4,
      h: cfg.h - 1.04,
      fontSize: 11.5,
      color: COLORS.ink,
      margin: 0,
      valign: "top",
      fit: "shrink",
    });
  }
}

function addArrow(slide, x, y, w, h, color = COLORS.teal) {
  slide.addShape(pptx.ShapeType.chevron, {
    x,
    y,
    w,
    h,
    line: { color, transparency: 100 },
    fill: { color, transparency: 6 },
  });
}

function validate(slide) {
  warnIfSlideHasOverlaps(slide, pptx);
  warnIfSlideElementsOutOfBounds(slide, pptx);
}

const coverImg = path.resolve(__dirname, "..", "..", "Doc", "ReadmeFigure", "CpMT-LandScape.png");

// Slide 1
{
  const slide = pptx.addSlide();
  addBackdrop(slide, "D4EEF5");
  slide.addShape(pptx.ShapeType.rect, {
    x: 0.7,
    y: 0.7,
    w: 6.55,
    h: 5.8,
    line: { color: "CFE6EC", width: 1.3 },
    fill: { color: COLORS.white },
  });
  slide.addShape(pptx.ShapeType.rect, {
    x: 7.35,
    y: 0.7,
    w: 5.25,
    h: 5.8,
    line: { color: "C7E8F0", width: 1.3 },
    fill: { color: "EFF9FC" },
  });
  slide.addText("CONSTRAINED MULTITASKING", {
    x: 1.0,
    y: 1.02,
    w: 3.6,
    h: 0.25,
    fontFace: "Georgia",
    fontSize: 10,
    bold: true,
    color: COLORS.teal,
    charSpace: 1.5,
  });
  slide.addText("CEDA_MP", {
    x: 1.0,
    y: 1.34,
    w: 3.8,
    h: 0.7,
    fontSize: 30,
    bold: true,
    color: COLORS.navy,
  });
  slide.addText("基于协同进化与领域适配的约束多任务优化方法", {
    x: 1.0,
    y: 2.06,
    w: 5.2,
    h: 0.6,
    fontSize: 18,
    color: COLORS.ink,
    bold: true,
  });
  slide.addText("根据仓库中的 `CEDA_MP.m`、`CEDA_trans.m`、诊断/追踪版本与扩展变体整理", {
    x: 1.0,
    y: 2.74,
    w: 5.6,
    h: 0.42,
    fontSize: 11.5,
    color: COLORS.slate,
  });
  addPill(slide, "Swarm and Evolutionary Computation, 2024", 1.0, 3.35, 3.8, COLORS.sand);
  addPill(slide, "MToP 平台实现", 4.95, 3.35, 1.4, "DCEFFD");
  slide.addText("核心关键词", {
    x: 1.0,
    y: 4.0,
    w: 1.3,
    h: 0.22,
    fontSize: 11,
    bold: true,
    color: COLORS.slate,
  });
  addPill(slide, "双群体协同", 1.0, 4.32, 1.4, "E6F7FF");
  addPill(slide, "epsilon 约束", 2.55, 4.32, 1.55, "F8F3CF");
  addPill(slide, "领域适配迁移", 4.25, 4.32, 1.75, "E7F8EB");
  slide.addText("作者注释中的默认参数体现出不对称迁移策略：`RMP1 = 0.15`，`RMP2 = 0`。", {
    x: 1.0,
    y: 5.05,
    w: 5.6,
    h: 0.5,
    fontSize: 12.5,
    color: COLORS.ink,
    margin: 0,
  });
  slide.addImage({
    path: coverImg,
    ...imageSizingContain(coverImg, 7.68, 1.0, 4.55, 2.7),
  });
  slide.addText("约束多任务优化需要同时处理", {
    x: 7.78,
    y: 4.1,
    w: 3.8,
    h: 0.24,
    fontSize: 11,
    color: COLORS.slate,
  });
  addBulletList(slide, [
    "跨任务知识共享是否有效",
    "可行域稀缺导致的搜索停滞",
    "不同任务分布差异下的迁移失真",
  ], { x: 7.8, y: 4.38, w: 4.25, h: 1.55 }, COLORS.ink, 13.2);
  addFooter(slide, 1);
  validate(slide);
}

// Slide 2
{
  const slide = pptx.addSlide();
  addBackdrop(slide, "E6F7EC");
  addTitle(slide, "WHY IT MATTERS", "问题背景与 CEDA_MP 的切入点", "约束多任务优化里，单纯“共享”知识不够，关键是共享什么、何时共享、怎样映射。");
  addCard(slide, {
    x: 0.85, y: 2.0, w: 3.85, h: 3.95,
    label: "挑战", labelFill: COLORS.coral, labelWidth: 1.05,
    fill: COLORS.white,
    body: "1. 多任务间决策空间维度或统计特征不一致，直接迁移容易破坏结构。\n\n2. 约束会让早期群体以不可行为主，单一选择压力容易错失潜在优质区域。\n\n3. 若只保守追求可行解，探索性下降；若只追求探索，又会长期停在不可行区。"
  });
  addCard(slide, {
    x: 4.92, y: 2.0, w: 3.7, h: 3.95,
    label: "思路", labelFill: COLORS.sky, labelWidth: 1.05,
    fill: "FDFEFE",
    body: "CEDA_MP 用两个并行群体协同推进：\n\nPop1 采用 epsilon 约束选择，允许“近可行”解参与竞争；\n\nPop2 采用严格约束选择，维持可行性收敛方向；\n\n两者共享后代评估结果，但承担不同搜索职责。"
  });
  addCard(slide, {
    x: 8.82, y: 2.0, w: 3.65, h: 3.95,
    label: "迁移", labelFill: "E7F8EB", labelWidth: 1.05,
    fill: COLORS.white,
    body: "跨任务知识不是原样拷贝，而是先做领域适配：\n\n将源任务样本在协方差与均值层面映射到目标任务分布，再参与交叉变异。\n\n默认只在 Pop1 打开迁移通道，体现“探索通道更开放、收敛通道更谨慎”的设计。"
  });
  slide.addText("一句话概括：CEDA_MP 不是简单叠加“协同进化 + 迁移”，而是用双群体把探索与可行性推进拆开，再通过适配后的迁移增强探索通道。", {
    x: 0.95, y: 6.25, w: 11.8, h: 0.55, fontSize: 13, color: COLORS.ink,
  });
  addFooter(slide, 2);
  validate(slide);
}

// Slide 3
{
  const slide = pptx.addSlide();
  addBackdrop(slide, "FFF2D8");
  addTitle(slide, "FRAMEWORK", "CEDA_MP 总体框架", "代码里的 `run()` 函数可以直接对应成“初始化 - 任务内选择 - 任务间配对 - 生成后代 - 精英更新”的循环。");

  addCard(slide, {
    x: 0.92, y: 2.1, w: 2.25, h: 2.0, label: "Step 1", labelFill: COLORS.sky,
    title: "初始化双群体",
    body: "每个任务各维护 `population1` 与 `population2`。\n并基于 Pop1 的约束违反值计算初始 epsilon 阈值 `Ep0`。"
  });
  addArrow(slide, 3.28, 2.8, 0.55, 0.35);
  addCard(slide, {
    x: 3.92, y: 2.1, w: 2.35, h: 2.0, label: "Step 2", labelFill: COLORS.sand,
    title: "任务内选择父代",
    body: "Pop1：对 CV 先做 epsilon 松弛后锦标赛选择。\nPop2：按原始 CV 与 Obj 严格选择。"
  });
  addArrow(slide, 6.42, 2.8, 0.55, 0.35);
  addCard(slide, {
    x: 7.02, y: 2.1, w: 2.55, h: 2.0, label: "Step 3", labelFill: "E7F8EB",
    title: "随机配对其他任务",
    body: "对每个任务 t，随机选另一个任务 k。\n以 `population{k}(mating_pool{k})` 作为迁移知识来源。"
  });
  addArrow(slide, 9.72, 2.8, 0.55, 0.35);
  addCard(slide, {
    x: 10.3, y: 2.1, w: 2.05, h: 2.0, label: "Step 4", labelFill: COLORS.coral,
    title: "评估与精英更新",
    body: "合并两个通道生成的后代。\n同一批后代分别更新 Pop1 与 Pop2。"
  });

  slide.addShape(pptx.ShapeType.roundRect, {
    x: 1.05, y: 4.55, w: 5.0, h: 1.52, rectRadius: 0.05,
    line: { color: "B8DDE8", width: 1.1 }, fill: { color: COLORS.white }
  });
  slide.addText("Pop1：松弛约束 + 迁移主通道", {
    x: 1.28, y: 4.8, w: 2.3, h: 0.24, fontSize: 14.5, bold: true, color: COLORS.teal
  });
  addBulletList(slide, [
    "使用 `Generation1()`",
    "有概率触发迁移 `RMP1`",
    "选择时用 `Selection_Elit(..., Ep)`",
  ], { x: 1.25, y: 5.13, w: 4.45, h: 0.72 }, COLORS.ink, 11.5);

  slide.addShape(pptx.ShapeType.roundRect, {
    x: 7.0, y: 4.55, w: 5.0, h: 1.52, rectRadius: 0.05,
    line: { color: "D9DCC0", width: 1.1 }, fill: { color: "FFFCF0" }
  });
  slide.addText("Pop2：严格约束 + 稳定收敛通道", {
    x: 7.25, y: 4.8, w: 2.4, h: 0.24, fontSize: 14.5, bold: true, color: COLORS.red
  });
  addBulletList(slide, [
    "使用 `Generation2()`",
    "默认 `RMP2 = 0`，关闭迁移",
    "选择时用 `Selection_Elit(..., 0)`",
  ], { x: 7.23, y: 5.13, w: 4.45, h: 0.72 }, COLORS.ink, 11.5);

  slide.addText("两个群体共享后代评价，但选择压力不同，因此形成“探索 - 收敛”分工。", {
    x: 0.98, y: 6.45, w: 11.5, h: 0.3, fontSize: 12.5, color: COLORS.slate
  });
  addFooter(slide, 3);
  validate(slide);
}

// Slide 4
{
  const slide = pptx.addSlide();
  addBackdrop(slide, "EAF7FF");
  addTitle(slide, "MECHANISMS", "两个最关键的机制", "一个决定如何处理约束，一个决定如何把别的任务知识“翻译”过来。");

  addCard(slide, {
    x: 0.95, y: 2.0, w: 5.55, h: 4.15,
    label: "Mechanism A", labelFill: COLORS.sand, labelWidth: 1.65,
    title: "epsilon 约束驱动的分阶段搜索",
    body: "代码中先从 Pop1 的前 `EC_Top` 比例样本估计初始阈值 `Ep0`，随后按\n\nEp = Ep0 × (1 - FE / (EC_Tc × maxFE)) ^ EC_Cp\n\n逐渐衰减到 0。\n\n含义是：前期允许轻微违反约束的个体与可行个体一同竞争，帮助跳出稀疏可行域；后期则逐步回归严格可行性。"
  });
  addCard(slide, {
    x: 6.82, y: 2.0, w: 5.55, h: 4.15,
    label: "Mechanism B", labelFill: "DDF3E2", labelWidth: 1.65,
    title: "领域适配后的跨任务迁移",
    body: "`CEDA_trans.m` 中通过均值与协方差对齐完成样本映射：\n\nx' = (x - mu_s) · C_s^(-1/2) · C_t^(1/2) + mu_t\n\n并且同时保留源到目标、目标到源的双向映射候选，再随机选取迁移样本。\n\n这样做的目的，是把“源任务的结构信息”转换成更适配目标任务分布的搜索起点。"
  });

  slide.addText("为什么默认只给 Pop1 开迁移？", {
    x: 1.1, y: 6.35, w: 2.2, h: 0.24, fontSize: 12.8, bold: true, color: COLORS.navy
  });
  slide.addText("因为 Pop1 更像探索通道，允许引入带风险但高价值的外部知识；Pop2 则更像守住可行性的稳定器。", {
    x: 3.35, y: 6.35, w: 8.6, h: 0.24, fontSize: 12.8, color: COLORS.ink
  });
  addFooter(slide, 4);
  validate(slide);
}

// Slide 5
{
  const slide = pptx.addSlide();
  addBackdrop(slide, "F5F8DC");
  addTitle(slide, "IMPLEMENTATION", "仓库实现如何对应算法设计", "如果要讲代码，这一页可以直接作为“文件地图”。");

  addCard(slide, {
    x: 0.9, y: 2.0, w: 3.35, h: 1.6, label: "主类", labelFill: COLORS.sky, labelWidth: 0.95,
    title: "CEDA_MP.m",
    body: "主流程入口。\n定义参数、`run()` 主循环、`Generation1()` 和 `Generation2()`。"
  });
  addCard(slide, {
    x: 0.9, y: 3.85, w: 3.35, h: 1.6, label: "映射", labelFill: COLORS.sand, labelWidth: 0.95,
    title: "CEDA_trans.m",
    body: "迁移前的领域适配模块。\n核心是均值对齐 + 协方差白化/着色。"
  });
  addCard(slide, {
    x: 4.45, y: 2.0, w: 3.8, h: 1.6, label: "追踪", labelFill: "DDF3E2", labelWidth: 0.95,
    title: "CEDA_MP_Trace.m",
    body: "在不改变逻辑的前提下，额外记录每代的迁移占比、存活率、可行率、最优来源等指标。"
  });
  addCard(slide, {
    x: 4.45, y: 3.85, w: 3.8, h: 1.6, label: "诊断", labelFill: COLORS.coral, labelWidth: 0.95,
    title: "CEDA_MP_Diag.m / plot_CEDA_diag.m",
    body: "更偏机制分析。\n适合回答“迁移后代到底有没有活下来、什么时候改善了 Pop1/Pop2”这类问题。"
  });
  addCard(slide, {
    x: 8.45, y: 2.0, w: 3.95, h: 3.45, label: "变体", labelFill: "E9EDF8", labelWidth: 0.95,
    title: "扩展族",
    body: "仓库里还包含一系列基于 CEDA_MP 的派生版本：\n\n`CEDA_MP_ARMP` 自适应 RMP\n`CEDA_MP_DUALCHANNEL` 双通道迁移\n`CEDA_MP_FEASCHANNEL` 可行通道映射\n`CEDA_MP_TRIGGER` 触发式迁移\n\n这说明 CEDA_MP 已成为该目录下的核心母体框架。"
  });
  slide.addText("默认参数", {
    x: 0.95, y: 5.9, w: 0.82, h: 0.22, fontSize: 11.5, bold: true, color: COLORS.navy
  });
  addPill(slide, "EC_Top = 0.2", 1.95, 5.83, 1.35, "EDF7FF");
  addPill(slide, "EC_Tc = 0.8", 3.45, 5.83, 1.35, "FFF7D6");
  addPill(slide, "EC_Cp = 5", 4.95, 5.83, 1.25, "E8F8EB");
  addPill(slide, "RMP1 = 0.15", 6.35, 5.83, 1.45, "FFEAE3");
  addPill(slide, "RMP2 = 0", 7.95, 5.83, 1.18, "E9EFFB");
  slide.addText("这些值共同塑造了“前期松弛、单边迁移、后期收紧”的默认行为。", {
    x: 0.95, y: 6.38, w: 10.8, h: 0.26, fontSize: 12.2, color: COLORS.slate
  });
  addFooter(slide, 5);
  validate(slide);
}

// Slide 6
{
  const slide = pptx.addSlide();
  addBackdrop(slide, "FCEFE6");
  addTitle(slide, "DIAGNOSTICS", "从追踪与诊断版本能读出什么", "虽然主类只负责求解，但仓库已经提供了机制验证所需的观测接口。");

  addCard(slide, {
    x: 0.92, y: 2.05, w: 3.85, h: 3.8,
    label: "Trace", labelFill: COLORS.sky, labelWidth: 1.0,
    title: "迁移后代质量",
    body: "`plot_CEDA_MP_trace.m` 会比较 transfer offspring 与 normal offspring 的严格/松弛排序、均值 CV、可行率与 top-half 占比。\n\n适合判断迁移个体是不是“看起来好、其实进不去”。"
  });
  addCard(slide, {
    x: 4.78, y: 2.05, w: 3.85, h: 3.8,
    label: "Survival", labelFill: COLORS.sand, labelWidth: 1.15,
    title: "迁移后代存活率",
    body: "日志会记录 Pop1 / Pop2 中 transfer offspring 的选中数量与存活比例。\n\n这直接回答一个关键问题：迁移究竟是在制造噪声，还是确实帮助了群体更新。"
  });
  addCard(slide, {
    x: 8.64, y: 2.05, w: 3.85, h: 3.8,
    label: "Impact", labelFill: "DDF3E2", labelWidth: 1.0,
    title: "群体前后效应",
    body: "诊断项还覆盖 Pop1 / Pop2 更新前后的最佳可行目标值、可行率与多样性。\n\n因此可以把 CEDA_MP 讲清楚为：迁移是否改变了群体，改变的是哪一个群体，以及这种改变是不是有益。"
  });
  slide.addText("做论文汇报时，这一页可以自然过渡到你自己的实验图：只要把 trace/diag 日志重新画成折线图即可。", {
    x: 1.0, y: 6.28, w: 11.2, h: 0.3, fontSize: 12.4, color: COLORS.ink
  });
  addFooter(slide, 6);
  validate(slide);
}

// Slide 7
{
  const slide = pptx.addSlide();
  addBackdrop(slide, "E8F4F7");
  addTitle(slide, "USE & TAKEAWAYS", "如何使用 CEDA_MP，以及汇报时可强调的结论", "最后一页既能做总结，也能给出复现实验入口。");

  addCard(slide, {
    x: 0.92, y: 2.0, w: 5.0, h: 3.9,
    label: "运行", labelFill: COLORS.sky, labelWidth: 0.9,
    title: "在 MToP 中调用",
    body: "示例命令：\n\nmto({CEDA_MP()}, {CMT5()}, 'Reps', 1)\n\n若需要机制分析，可改为：\n\nmto({CEDA_MP_Trace()}, {CMT5()}, 'Reps', 1, 'Global_Seed', 2333)\nplot_CEDA_MP_trace\n\n适合先小规模 smoke test，再扩大 `Reps` 或 `maxFE`。"
  });
  addCard(slide, {
    x: 6.15, y: 2.0, w: 3.0, h: 3.9,
    label: "优点", labelFill: "E7F8EB", labelWidth: 0.9,
    title: "汇报可强调",
    body: "1. 用双群体解耦探索与可行性推进。\n\n2. 用 epsilon 约束缓解早期可行解稀缺。\n\n3. 用领域适配提升跨任务迁移的可用性。\n\n4. 已形成完整变体家族，便于继续研究。"
  });
  addCard(slide, {
    x: 9.38, y: 2.0, w: 3.05, h: 3.9,
    label: "提醒", labelFill: COLORS.coral, labelWidth: 0.9,
    title: "答辩时可补充",
    body: "1. 默认迁移是不对称的，说明作者更信任探索通道。\n\n2. 迁移有效性最好用 trace/diag 指标实证。\n\n3. 若任务相关性弱，领域适配依然可能失真，需要自适应或触发式机制。"
  });
  slide.addText("总结", {
    x: 0.98, y: 6.2, w: 0.75, h: 0.24, fontSize: 12.8, bold: true, color: COLORS.navy
  });
  slide.addText("CEDA_MP 的价值不只在于一个算法结果，而在于它把“约束处理、跨任务迁移、机制可解释性”整合成了一套可扩展的实现框架。", {
    x: 1.82, y: 6.2, w: 10.3, h: 0.38, fontSize: 12.8, color: COLORS.ink
  });
  addFooter(slide, 7);
  validate(slide);
}

const outPath = path.resolve(__dirname, "CEDA_MP_内容解读.pptx");

pptx.writeFile({ fileName: outPath }).then(() => {
  console.log(`Wrote ${outPath}`);
}).catch((err) => {
  console.error(err);
  process.exit(1);
});
