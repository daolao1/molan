/// 写作 agent 的思维链:两阶段协议,由程序强制执行。
/// 调研阶段只挂载只读工具(写入工具物理不存在),模型产出【构思】后
/// 程序才在执行阶段放开全部工具——不依赖模型自觉。
///
/// 设计参考:
/// - Anthropic prompt engineering:investigate-before-answering(未读禁答)
/// - AIStoryWriter 多阶段 pipeline:每阶段独立请求、职责单一
library;

/// 只读工具名单:调研阶段仅提供这些(set_highlight 无害,允许用于定位)
const researchToolNames = {
  'read_content',
  'read_outline',
  'get_entry_detail',
  'list_entries',
  'list_chapters',
  'get_event_content',
  'set_highlight',
};

/// 附加在用户消息尾部的调研阶段指令
const researchPhaseSuffix = '''

【系统·调研阶段】本回合只提供检索/读取工具,写入工具尚未开放:
- 判断本条消息:若只是讨论、提问或找段落,直接回答/用 set_highlight 定位即可,不要输出【构思】
- 若需要写作或修改正文:先完成调研——read_content 读正文与高亮;查设定库中"文风""写作要求"类条目并严格遵守;出场人物逐个 get_entry_detail(性格、说话方式、称呼表、关系);检查伏笔;涉及其他章节用 get_event_content 核对原文,禁止凭记忆编造
- 然后从正文提炼文风基准(人称、时态、节奏、对白腔调;设定中的文风要求优先于推断)
- 最后输出一行以【构思】开头的写作计划:写什么、情节推进到哪、大约篇幅、用哪个工具,以及遵循的文风要点''';

/// 调研完成后注入的执行阶段指令
const executePhaseMessage = '''
【系统·执行阶段】写入工具已开放。严格按你的【构思】执行:
- 局部修改用 replace_text,续写用 append_text,不要为小改动整体重写
- 写完自检:人物言行与设定一致、称呼按说话人视角、与前文/大纲/伏笔无冲突、接缝处风格不断裂
- 情节走向变了同步 set_outline;新设定/人物变化/伏笔进展用 upsert_entry 记录
- 最后用一两句话向作者说明做了什么''';

/// system 提示词中对两阶段协议的说明
const writingChainOfThought = '''
两阶段写作协议(由系统强制,工具可用性随阶段变化):
- 调研阶段:系统只挂载读取/检索工具;完成设定与文风调研后,需要写作时以【构思】一行收尾,否则当作普通对话回答
- 执行阶段:你输出【构思】后,系统才开放写入工具并提示执行;按构思动笔,写完自检
- 不要在调研阶段用文字描述"我将怎么改"来代替实际操作,执行阶段才真正动手''';
