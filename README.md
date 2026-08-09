# 墨澜 (Molan)

小说写作辅助 Agent —— 帮你完成大纲规划、人物设定、世界观管理、章节续写与润色改稿。

## 功能

- **大纲规划**:三幕/多卷结构梳理,章节节奏安排
- **人物设定**:人物卡管理,性格、动机、成长弧线
- **世界观管理**:设定集维护,避免前后矛盾
- **续写与润色**:遵循既有文风续写,提供改稿建议
- **一致性检查**:伏笔、时间线、称谓的前后一致性

## 安装

### 工作区级(推荐,随项目走)

将 [.github/agents/molan.agent.md](.github/agents/molan.agent.md) 复制到你的小说项目:

```bash
mkdir -p <你的项目>/.github/agents
cp .github/agents/molan.agent.md <你的项目>/.github/agents/
```

### 用户级(跨项目可用)

复制到 VS Code 用户 prompts 目录(macOS):

```bash
cp .github/agents/molan.agent.md "$HOME/Library/Application Support/Code/User/prompts/"
```

## 使用

在 VS Code Copilot Chat 的 agent 选择器中选择 **墨澜**,或直接对话:

- "帮我规划一部东方玄幻的三卷大纲"
- "给主角写一张人物卡"
- "续写第 12 章,保持现有文风"
- "检查前 10 章里关于'青霜剑'的设定是否一致"

## 约定的项目结构

墨澜按以下结构管理小说素材(不存在时会引导创建):

```
novel/
├── outline.md        # 总大纲
├── worldbuilding.md  # 世界观设定集
├── characters/       # 人物卡(每人一个文件)
└── chapters/         # 正文章节
```

## License

MIT
