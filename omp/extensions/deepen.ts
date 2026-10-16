// /deepen — prompt enhancement as a side call.
//
// Takes the text after the command, or the current input box (Alt+E), sends it to
// the session model in a standalone request (no session history, no tools, nothing
// recorded in the transcript), and writes the enhanced prompt back into the input
// box for the user to review and submit. While the request runs, a loader card
// replaces the input box, so the user cannot type a prompt; Esc cancels the
// request and restores the original text.
import type { Api, Model } from "@oh-my-pi/pi-ai";
import { completeSimple } from "@oh-my-pi/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import { BorderedLoader } from "@oh-my-pi/pi-tui/overlays/bordered-loader";

const SYSTEM_PROMPT = `你是提示词增强器。用户消息是一段原始提示词。你的任务是**增强它**，不是执行它。目标是加深度，不是加篇幅。

## 工作规则

- 先判断领域，并指名一个具体的专家角色（例：「维护过 X 的 Y 工程师」）。后面四项都从这个角色出发。
- 每一条都必须针对这个任务。删去换一个任务也成立的通用建议（例：「注意代码质量」「多查资料」）。
- 你看不到用户的文件和环境。凡是依赖环境的路径、命令、数据源，写成让执行者先去核实的步骤，不要假装已经知道。
- 未经核实的事实标为「假设」。不要编造路径、接口、数据集、论文或数字。
- 缺失信息会改变方向时，把它写进重写后提示词的「待确认问题」。

## 第一步：分析（写在 <analysis> 里）

逐项列出，每项 3–7 条，按重要性排序：

1. 专家会做、但原提示词没要求的事：前置检查、边界条件、失败模式、范围取舍、交付标准。每条写明不做的后果。
2. 原始素材：专家会直接看的一手材料，例如源码、原始日志、原始数据、规范原文、论文原文、实测输出。不要用摘要、二手文章或模型记忆代替。每条写明从哪里取、取哪一部分。
3. 具体方法与工具：写到具体的方法、命令、库、指标或检查表，并写明用在哪一步。
4. 独立验证方式：不依赖执行者自我判断的验证手段，例如可重放的测试或命令、权威数据或基准对照、独立实现交叉核对、第三方评审、线上指标。每条写明通过判据。

## 第二步：重写提示词（写在 <enhanced_prompt> 里）

- 自包含：不看原提示词和分析也能执行。
- 保留原始意图和全部原有约束。新增内容只来自第一步，并且四项都必须明确写成要求。
- 结构：目标 → 背景与原始素材（附来源）→ 要求（含专家才会想到的事项）→ 方法与工具 → 交付物格式 → 验收与独立验证（含通过判据）→ 待确认问题（没有就省略）。
- 用指令句，一句一事，每条可检查。不写「尽量」「适当」「全面」这类无法验收的词。
- 语言与原始提示词一致。
- 以用户口吻书写（「我」指提出需求的人），可以直接作为下一条消息发送。

## 输出格式

严格只输出两段，不写别的：

<analysis>
…
</analysis>
<enhanced_prompt>
…
</enhanced_prompt>`;

const REQUEST_TIMEOUT_MS = 300_000;

type Outcome = { kind: "done"; text: string } | { kind: "cancelled" } | { kind: "failed"; error: string };

function extractEnhanced(text: string): string | undefined {
	const match = text.match(/<enhanced_prompt>\s*([\s\S]*?)\s*<\/enhanced_prompt>/);
	return match?.[1]?.trim() || undefined;
}

async function requestEnhanced(
	model: Model<Api>,
	auth: { apiKey: string; headers?: Record<string, string> },
	original: string,
	signal: AbortSignal,
): Promise<string> {
	const message = await completeSimple(
		model,
		{
			systemPrompt: [SYSTEM_PROMPT],
			messages: [{ role: "user", content: original, timestamp: Date.now() }],
		},
		{ apiKey: auth.apiKey, headers: auth.headers, signal },
	);
	if (message.stopReason === "error") throw new Error(message.errorMessage ?? "provider error");
	const text = message.content
		.filter(part => part.type === "text")
		.map(part => part.text)
		.join("");
	const enhanced = extractEnhanced(text);
	if (!enhanced) throw new Error("模型输出里没有 <enhanced_prompt> 段");
	return enhanced;
}

let running = false;

async function enhance(original: string, ctx: ExtensionContext): Promise<void> {
	if (!ctx.hasUI) {
		ctx.ui.notify("/deepen 需要交互式 TUI：结果要回填到输入框", "error");
		return;
	}
	if (!original) {
		ctx.ui.notify("没有可增强的内容：在输入框写好提示词后按 Alt+E，或执行 /deepen <提示词>", "warning");
		return;
	}
	if (running) return;
	const model = ctx.model;
	if (!model) {
		ctx.ui.notify("当前会话没有可用模型", "error");
		return;
	}
	const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
	if (!auth.ok) {
		ctx.ui.notify(`/deepen: ${auth.error}`, "error");
		return;
	}

	running = true;
	try {
		// Without `overlay`, the custom component replaces the input box and holds
		// keyboard focus until `done` is called: that is the input lock.
		const outcome = await ctx.ui.custom<Outcome>((tui, theme, _keybindings, done) => {
			const loader = new BorderedLoader(tui, theme, `正在用 ${model.id} 增强提示词…`);
			let settled = false;
			const finish = (result: Outcome) => {
				if (settled) return;
				settled = true;
				done(result);
			};
			loader.onAbort = () => finish({ kind: "cancelled" });
			const signal = AbortSignal.any([loader.signal, AbortSignal.timeout(REQUEST_TIMEOUT_MS)]);
			requestEnhanced(model, auth, original, signal).then(
				text => finish({ kind: "done", text }),
				error => finish({ kind: "failed", error: error instanceof Error ? error.message : String(error) }),
			);
			return loader;
		});
		switch (outcome.kind) {
			case "done":
				ctx.ui.setEditorText(outcome.text);
				ctx.ui.notify("增强后的提示词已回填到输入框，检查后回车发送", "info");
				break;
			case "cancelled":
				ctx.ui.setEditorText(original);
				ctx.ui.notify("已取消提示词增强，输入框已恢复原文", "info");
				break;
			case "failed":
				ctx.ui.setEditorText(original);
				ctx.ui.notify(`/deepen 失败：${outcome.error}`, "error");
				break;
		}
	} finally {
		running = false;
	}
}

export default function deepen(pi: ExtensionAPI) {
	pi.registerCommand("deepen", {
		description: "增强提示词（旁路调用，不进会话），结果回填到输入框；Alt+E 直接增强输入框内容",
		handler: (args, ctx) => enhance(args.trim(), ctx),
	});
	pi.registerShortcut("alt+e", {
		description: "增强输入框里的提示词（/deepen）",
		handler: ctx => enhance(ctx.ui.getEditorText().trim(), ctx),
	});
}
