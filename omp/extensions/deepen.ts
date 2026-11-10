/**
 * /deepen — 旁路「加深」提示词：把一句话需求扩成可执行、可验收的深度提示词。
 *
 * ## 状态机（先看这张表，代码里每个分支都对应其中一格）
 *
 * | 状态           | 触发                                   | 对输入框的影响                                   |
 * |----------------|----------------------------------------|--------------------------------------------------|
 * | `idle`         | 初始 / 一次运行结束                     | 不动                                             |
 * | `running`      | 已发出请求                             | **不动、不锁**：输入框照常打字，进度只写状态栏     |
 * | `success`      | 返回非空且草稿未被改                    | 回填增强结果（不自动发送）                        |
 * | `failure`      | 缺凭据 / HTTP 错 / 返回空 / 全部候选失败 | 不动，只 notify 报错                             |
 * | `cancel`       | 取消键、`/deepen cancel`、超时、关机     | 不动                                             |
 * | `draft-changed`| 请求期间草稿变了                        | 不动；结果暂存，`/deepen apply` 或再按 alt+e 取回 |
 * | `headless`     | 非交互模式（print/RPC/JSON）            | 没有输入框可回填 → 记日志 + 明确告警后返回         |
 *
 * ## 为什么这样分层
 *
 * 旧版用 `ctx.ui.custom(BorderedLoader)` 把输入框换成加载卡片：请求期间用户不能打字，
 * 而且要 import `@oh-my-pi/pi-tui/overlays/bordered-loader` 这种子路径（宿主升级就断）。
 * 新版只用 `@oh-my-pi/pi-coding-agent` 的公开类型 + `ctx.ui.setStatus/getEditorText/setEditorText`，
 * 请求期间**完全不碰 UI 焦点**。
 * 类比 C++：旧版像在主线程跑一个模态对话框，新版是把任务丢到后台线程、主线程只更新状态栏，
 * 代价是必须自己处理「用户期间改了草稿」这种竞态 —— 这正是 `draft-changed` 那一格。
 *
 * 模型默认直连便宜的 `deepseek-flash`（OpenAI 兼容 `/chat/completions`），凭据取环境变量
 * `DEEPSEEK_API_KEY`。为什么不走会话模型：加深提示词是「写作」不是「编码」，固定便宜模型更可预测，
 * 也不会因为会话挂着 opus 之类贵模型而烧钱；直连还省掉 agent 的系统提示词与工具定义（几千 token）。
 * 类比 Python：把一次调用从「依赖当前解释器全局状态」改成「显式传参的纯函数」，依赖面缩到一个环境变量。
 *
 * 入口两个，共用同一个内部函数 `run()`：`/deepen [style] [text…]` 与快捷键 `alt+e`。
 * 区别只在 `explicitText`：命令形态由参数提供文本（slash command 会吃掉整行输入），
 * 快捷键形态 `explicitText === undefined`，文本取自输入框。
 * 取消入口是 `alt+shift+e` 与 `/deepen cancel`，两者都 abort 同一个 `AbortController`。
 */
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

/** 三种加深策略。`select()` 只回传 label 字符串，所以 label 必须能反查回 style。 */
type Style = "deep" | "quick" | "spec";

const STYLES: readonly Style[] = ["deep", "quick", "spec"];

/** 选择器与补全里显示的一句话说明。 */
const STYLE_DESCRIPTIONS: Record<Style, string> = {
	deep: "Full depth: expert role, primary sources, method, independent verification",
	quick: "Light touch: keep the draft, add only the few checks that matter",
	spec: "Engineering spec: goal, inputs, steps, deliverables, acceptance criteria",
};

/** 不指定风格时的默认风格：deepen 的存在意义就是「加深」，默认给全套。 */
const DEFAULT_STYLE: Style = "deep";

/**
 * 共享前言。三种风格都先声明「输出就是最终提示词本身」，这样我们不需要任何标签协议
 * （旧版要求模型吐 `<analysis>` + `<enhanced_prompt>`，模型一旦不照做就解析失败）。
 * 类比 Python：与其约定一个自定义序列化格式再写 parser，不如约定「只返回纯文本」，
 * 解析退化成 `strip()`，失败面小一个数量级。
 */
const PREAMBLE = [
	"You deepen prompts for a coding agent. The user message is a raw prompt; your job is to DEEPEN it, not to execute it.",
	"Add depth, not length. Every added line must be specific to this task; delete anything that would be true for any other task.",
	"You cannot see the user's files or environment: write environment-dependent paths, commands and data sources as steps the executor must verify first, and mark unverified facts as assumptions.",
	"Never invent paths, APIs, datasets, papers or numbers.",
	"Output ONLY the rewritten prompt as plain text, in the user's original language, written in the user's voice so it can be sent as the next message.",
	"No preamble, no explanation, no analysis section, no quoting, no Markdown fences.",
].join("\n");

const SYSTEM_DEEP = [
	PREAMBLE,
	"Structure the result as: goal → background and primary sources (say where to get each) → requirements (including what an expert would ask for and the cost of skipping it) → method and tools → deliverable format → acceptance and independent verification (with pass criteria) → open questions (omit if none).",
	"Use imperative sentences, one requirement per sentence, each checkable. Avoid words that cannot be verified, such as 'appropriately' or 'thoroughly'.",
].join("\n");

const SYSTEM_QUICK = [
	PREAMBLE,
	"Keep the user's original wording and structure. Add only the few highest-value items: the expert role, the primary sources to read, the two or three failure modes, and how to verify success.",
	"Stay under roughly twice the length of the original.",
].join("\n");

const SYSTEM_SPEC = [
	PREAMBLE,
	"Rewrite the prompt as an engineering spec: goal, inputs and where they come from, numbered implementation steps, deliverables, constraints, and explicit acceptance criteria with the command or test that proves each one.",
	"Keep code, commands, file paths and identifiers from the original verbatim.",
].join("\n");

const SYSTEM_BY_STYLE: Record<Style, string> = {
	deep: SYSTEM_DEEP,
	quick: SYSTEM_QUICK,
	spec: SYSTEM_SPEC,
};

/** 状态栏与 notify 用的 key，保持唯一，避免和别的扩展抢同一格。 */
const STATUS_KEY = "deepen";

/** 运行快捷键：加深输入框草稿；空闲且有暂存结果时改为取回结果。omp 默认键位未占用 `alt+e`。 */
const RUN_KEY = "alt+e";
/** 取消快捷键：abort 正在跑的加深请求。`alt+shift+e` 在 omp 默认键位里同样空闲。 */
const CANCEL_KEY = "alt+shift+e";

/** 默认模型：omp catalog 里的 `deepseek/deepseek-flash`，直连时只取 `/` 后面的 wire id。 */
const DEFAULT_MODEL = "deepseek/deepseek-flash";
/** DeepSeek 官方 OpenAI 兼容端点（不带 `/v1`，与 omp 内建 deepseek provider 的 baseUrl 一致）。 */
const DEFAULT_BASE_URL = "https://api.deepseek.com";
/** 凭据环境变量名，与 omp 内建 deepseek provider 的 `env` 声明同名。 */
const DEFAULT_API_KEY_ENV = "DEEPSEEK_API_KEY";
/** 输出上限。加深后的提示词最多几百行，8192 留足余量又不至于让模型跑飞。 */
const DEFAULT_MAX_TOKENS = 8192;
/** 整个运行（含备用模型重试）的墙钟上限；到点 abort，走 `cancel` 那一格。 */
const REQUEST_TIMEOUT_MS = 120_000;

/**
 * 一次请求的完整目标：模型 + 端点 + 凭据变量。
 * 把三者绑成一个值而不是三个平行变量，是为了让「主配置」与「内置默认」能整体比较、
 * 整体去重 —— 类比 C++ 的 struct 传值，比传三个参数更难传错顺序。
 */
interface Candidate {
	model: string;
	baseUrl: string;
	apiKeyEnv: string;
}

/** 配置文件形状，全部可选；缺项等价于内置默认。 */
interface DeepenConfig {
	style?: Style;
	model?: string;
	baseUrl?: string;
	apiKeyEnv?: string;
	maxTokens?: number;
	/** 整体替换内置风格提示词。 */
	system?: string;
}

/** 读配置的结果：清洗后的配置 + 被拒绝的字段名（用于提示用户「坏配置回默认」）。 */
interface ConfigRead {
	config: DeepenConfig;
	rejected: string[];
}

/** 状态机的七格。写成联合类型而不是散落的布尔量，是为了让每个 notify 都能说清自己在哪一格。 */
type Phase = "idle" | "running" | "success" | "failure" | "cancel" | "draft-changed" | "headless";

/**
 * 配置文件路径。
 *
 * 为什么自己算而不用 `getAgentDir()`：扩展跑在 omp 的模块加载器里，导入 `@oh-my-pi/pi-utils`
 * 的解析结果取决于加载器把包重写到哪一份实现（历史上有 legacy shim 指向 `~/.pi/agent` 的坑）。
 * 直接按环境变量 + HOME 推导，行为可预测；顺序：显式覆盖 → OMP/PI 配置目录 → 默认 `~/.omp`。
 */
function configPath(): string {
	const explicit = process.env.OMP_DEEPEN_CONFIG;
	if (explicit) return explicit;
	const root = process.env.OMP_CONFIG_DIR ?? process.env.PI_CONFIG_DIR ?? path.join(os.homedir(), ".omp");
	return path.join(root, "agent", "extensions", "deepen.json");
}

/**
 * 读配置。文件缺失、JSON 坏掉、字段类型不对，一律退回默认值并把字段名记进 `rejected`，
 * 绝不让一次加深因为配置读取失败。类比 Python：相当于 `try: cfg = json.load(f) except: cfg = {}`
 * 再逐字段做 isinstance 校验，而不是信任整个 dict。
 */
function readConfig(): ConfigRead {
	const rejected: string[] = [];
	const config: DeepenConfig = {};
	let parsed: Record<string, unknown>;
	try {
		const raw = JSON.parse(fs.readFileSync(configPath(), "utf8")) as unknown;
		if (!raw || typeof raw !== "object" || Array.isArray(raw)) return { config, rejected: ["<file>"] };
		parsed = raw as Record<string, unknown>;
	} catch {
		// 文件不存在是正常情况（大多数人不会写配置），不算「坏配置」，所以不记 rejected。
		return { config, rejected };
	}

	const text = (value: unknown): string | undefined =>
		typeof value === "string" && value.trim().length > 0 ? value.trim() : undefined;

	if ("style" in parsed) {
		const style = normalizeStyle(parsed.style);
		if (style) config.style = style;
		else rejected.push("style");
	}
	for (const key of ["model", "apiKeyEnv", "system"] as const) {
		if (!(key in parsed)) continue;
		const value = text(parsed[key]);
		if (value) config[key] = value;
		else rejected.push(key);
	}
	if ("baseUrl" in parsed) {
		const value = text(parsed.baseUrl)?.replace(/\/+$/, "");
		// 端点必须是 http(s)，否则 fetch 直接抛 TypeError，用户只看到一句莫名其妙的错。
		if (value && /^https?:\/\//.test(value)) config.baseUrl = value;
		else rejected.push("baseUrl");
	}
	if ("maxTokens" in parsed) {
		const value = parsed.maxTokens;
		if (typeof value === "number" && Number.isSafeInteger(value) && value > 0) config.maxTokens = value;
		else rejected.push("maxTokens");
	}
	return { config, rejected };
}

/** 把 style 写回配置文件（`/deepen style` 的持久化）。只覆盖一个字段，其余原样保留。 */
function persistStyle(style: Style): void {
	const file = configPath();
	let current: Record<string, unknown> = {};
	try {
		const raw = JSON.parse(fs.readFileSync(file, "utf8")) as unknown;
		if (raw && typeof raw === "object" && !Array.isArray(raw)) current = raw as Record<string, unknown>;
	} catch {
		// 没有文件或文件坏掉：从空对象重建，等于「用默认值 + 新风格」落盘。
	}
	current.style = style;
	fs.mkdirSync(path.dirname(file), { recursive: true });
	fs.writeFileSync(file, `${JSON.stringify(current, null, 2)}\n`, "utf8");
}

/**
 * 候选模型列表：第一个是用户配置（缺项补默认），第二个是纯内置默认。
 * 三项全相等时只留一个 —— 否则「主模型失败 → 用同一个模型再试一次」是纯浪费。
 * 这就是「备用模型」通道：配置指向的模型挂了，自动退到内置默认，用户不用改配置。
 */
function candidates(config: DeepenConfig): Candidate[] {
	const configured: Candidate = {
		model: config.model ?? DEFAULT_MODEL,
		baseUrl: config.baseUrl ?? DEFAULT_BASE_URL,
		apiKeyEnv: config.apiKeyEnv ?? DEFAULT_API_KEY_ENV,
	};
	const fallback: Candidate = { model: DEFAULT_MODEL, baseUrl: DEFAULT_BASE_URL, apiKeyEnv: DEFAULT_API_KEY_ENV };
	const same =
		configured.model === fallback.model &&
		configured.baseUrl === fallback.baseUrl &&
		configured.apiKeyEnv === fallback.apiKeyEnv;
	return same ? [configured] : [configured, fallback];
}

/** `<provider>/<id>` 只取后半段当 wire id（`deepseek/deepseek-flash` → `deepseek-flash`）。 */
function wireModel(spec: string): string {
	return spec.slice(spec.lastIndexOf("/") + 1);
}

/**
 * 清洗模型输出 —— 按不可信输入处理。
 *
 * 模型偶尔无视「不要 Markdown 围栏」，把整段答案包在 ``` 里；只在这一种情形剥壳
 * （首行是 ``` 且末行是 ```），正文里合法的代码块保持原样。
 * 空结果不在这里报错，而是交给调用方 —— 调用方需要区分「模型返回空」和「剥壳后为空」。
 * 类比 Python：`text.split("\n")` 后判断首尾行，和 `str.strip()` 一个套路。
 */
function sanitizeReply(reply: string): string {
	const text = reply.trim();
	const lines = text.split("\n");
	if (lines.length >= 2 && lines[0]?.trimStart().startsWith("```") && lines[lines.length - 1]?.trim() === "```") {
		return lines.slice(1, -1).join("\n").trim();
	}
	return text;
}

/**
 * 从 OpenAI 兼容响应里取文本。content 可能是字符串，也可能是 `[{type:"text",text}]` 分段
 * （部分网关即使 `stream:false` 也返回数组）。两种都收，其余形状当「没有内容」。
 */
function extractContent(payload: unknown): string | undefined {
	if (!payload || typeof payload !== "object" || !("choices" in payload)) return undefined;
	const { choices } = payload;
	if (!Array.isArray(choices)) return undefined;
	const [first] = choices as unknown[];
	if (!first || typeof first !== "object" || !("message" in first)) return undefined;
	const { message } = first;
	if (!message || typeof message !== "object" || !("content" in message)) return undefined;
	const { content } = message;
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return undefined;
	const parts = (content as unknown[])
		.map(part => (part && typeof part === "object" && "text" in part ? part.text : undefined))
		.filter((text): text is string => typeof text === "string");
	return parts.length > 0 ? parts.join("") : undefined;
}

/**
 * 直连 OpenAI 兼容 `/chat/completions`。
 *
 * 为什么手写 fetch 而不复用 omp 的 provider 层：omp 没把 pi-ai 的 `streamSimple` 暴露给扩展
 * （`pi.pi` 里没有），从扩展里 import `@oh-my-pi/pi-ai` 会让 bun 在扩展目录再装一份 pi-ai，
 * 与宿主那份不同步。这个调用本身只有一个 HTTP 请求 + 一个环境变量，手写依赖更少。
 *
 * `thinking: { type: "disabled" }`：deepseek-flash 默认开思考，改写任务不需要；别的
 * OpenAI 兼容端点会忽略未知字段。
 */
async function requestDeepened(
	system: string,
	draft: string,
	candidate: Candidate,
	maxTokens: number,
	signal: AbortSignal,
): Promise<string> {
	const apiKey = process.env[candidate.apiKeyEnv];
	if (!apiKey) throw new Error(`${candidate.apiKeyEnv} is not set`);
	const wire = wireModel(candidate.model);

	// 用 `<draft>` 定界而不是「system 里说、user 里只放文本」，是为了让模型在多行草稿里
	// 也能明确边界（草稿本身可能包含指令样式的句子）。
	// 类比 Python：给输入加定界符，和 `csv` 用引号包字段是同一个动机。
	const user = `Deepen the prompt between the markers. Output only the deepened prompt.\n\n<draft>\n${draft}\n</draft>`;

	const response = await fetch(`${candidate.baseUrl}/chat/completions`, {
		method: "POST",
		headers: { "content-type": "application/json", authorization: `Bearer ${apiKey}` },
		body: JSON.stringify({
			model: wire,
			max_tokens: maxTokens,
			stream: false,
			thinking: { type: "disabled" },
			messages: [
				{ role: "system", content: system },
				{ role: "user", content: user },
			],
		}),
		signal,
	});

	if (!response.ok) {
		// 错误体可能是 JSON 也可能是网关的 HTML；截断后带上状态码，够定位（401=key、404=模型 id）。
		const detail = (await response.text().catch(() => "")).trim().slice(0, 300);
		throw new Error(`${wire} HTTP ${response.status}${detail ? `: ${detail}` : ""}`);
	}

	const content = extractContent(await response.json());
	if (content === undefined) throw new Error(`${wire} returned no message content`);
	return content;
}

export default function deepen(pi: ExtensionAPI) {
	/** 状态机当前格。每次转移都赋值，让 notify 与守卫读同一个真相源。 */
	let state: Phase = "idle";
	/** 运行中的请求；取消键、`/deepen cancel`、超时、`session_shutdown` 都 abort 它。 */
	let inFlight: AbortController | undefined;
	/** `draft-changed` 时暂存的结果，等用户显式取回。 */
	let pending: { text: string; style: Style; model: string } | undefined;

	/**
	 * 加深主流程：定文本来源 → 定风格 → 请求（主模型失败退备用）→ 回填。
	 *
	 * `explicitText` 来自 `/deepen <text>`：slash command 会把整行输入消费掉，那时输入框里
	 * 不可能还留着草稿，所以命令形态必须自己带上文本。快捷键形态相反，`explicitText` 为
	 * undefined，文本取自输入框。
	 */
	async function run(ctx: ExtensionContext, options: { style?: Style; explicitText?: string }): Promise<void> {
		// headless：没有输入框可回填，早退并留下明确告警，而不是静默什么都不做。
		if (ctx.mode !== "tui" || !ctx.hasUI || ctx.ui.supportsEditor === false) {
			state = "headless";
			pi.logger.warn(`deepen: mode=${ctx.mode} hasUI=${ctx.hasUI} has no composer to fill back; skipped`);
			ctx.ui.notify("deepen: interactive TUI only — this mode has no composer to fill back", "warning");
			return;
		}
		if (state === "running") {
			ctx.ui.notify(`deepen: already running — ${CANCEL_KEY} or /deepen cancel stops it`, "warning");
			return;
		}

		const explicit = options.explicitText;
		const fromEditor = explicit === undefined;
		const source = explicit ?? ctx.ui.getEditorText();
		if (source.trim().length === 0) {
			ctx.ui.notify(
				fromEditor
					? `deepen: composer is empty — type a prompt, then press ${RUN_KEY}`
					: `deepen: nothing to deepen — pass the prompt as arguments or press ${RUN_KEY}`,
				"warning",
			);
			return;
		}

		// 回填前的比对基准：无论文本来自参数还是输入框，都记下此刻输入框的内容。
		// 请求期间用户完全可能继续打字；只有输入框没变，回填才不会吃掉用户的新内容。
		const editorAtStart = ctx.ui.getEditorText();

		const { config, rejected } = readConfig();
		if (rejected.length > 0) {
			ctx.ui.notify(`deepen: ignored bad config keys (${rejected.join(", ")}) in ${configPath()}`, "warning");
		}
		const style = options.style ?? config.style ?? DEFAULT_STYLE;
		const system = config.system ?? SYSTEM_BY_STYLE[style];
		const maxTokens = config.maxTokens ?? DEFAULT_MAX_TOKENS;
		const list = candidates(config);
		const primary = list[0]!;

		// 缺凭据直接失败，不退备用：备用模型可能用另一个环境变量的 key，静默换凭据会掩盖配置错误。
		if (!process.env[primary.apiKeyEnv]) {
			state = "failure";
			ctx.ui.notify(
				`deepen: ${primary.apiKeyEnv} is not set (needed by ${wireModel(primary.model)}) — export it or edit ${configPath()}`,
				"error",
			);
			return;
		}

		const controller = new AbortController();
		inFlight = controller;
		state = "running";
		const startedAt = Date.now();
		let timedOut = false;
		// 状态栏文案：模型 + 风格 + 已用秒数 + 取消键。用户不翻文档也知道怎么停。
		const refreshStatus = (): void => {
			const seconds = Math.round((Date.now() - startedAt) / 1000);
			ctx.ui.setStatus(STATUS_KEY, `🔍 deepening (${style} · ${wireModel(primary.model)}) ${seconds}s · ${CANCEL_KEY} cancel`);
		};
		// 超时与用户取消共用一个 controller：两者对请求的影响相同，只是提示文案不同。
		const deadline = ctx.setTimeout(() => {
			timedOut = true;
			controller.abort();
		}, REQUEST_TIMEOUT_MS);
		// 每秒刷一次状态栏，让用户看到「还在跑」而不是以为卡死。setInterval 由 omp 托管，
		// 抛错不会变成进程级 uncaughtException，会话结束时自动清。
		const ticker = ctx.setInterval(() => {
			if (state === "running") refreshStatus();
		}, 1000);
		refreshStatus();

		const failures: string[] = [];
		let raw: string | undefined;
		let used = primary;
		try {
			for (const candidate of list) {
				try {
					raw = await requestDeepened(system, source, candidate, maxTokens, controller.signal);
					used = candidate;
					break;
				} catch (error) {
					if (controller.signal.aborted) break;
					failures.push(`${wireModel(candidate.model)}: ${error instanceof Error ? error.message : String(error)}`);
				}
			}

			if (controller.signal.aborted) {
				state = "cancel";
				ctx.ui.notify(
					timedOut ? `deepen: timed out after ${REQUEST_TIMEOUT_MS / 1000}s — draft untouched` : "deepen: cancelled — draft untouched",
					"warning",
				);
				return;
			}
			if (raw === undefined) {
				state = "failure";
				ctx.ui.notify(`deepen: ${failures.join(" | ") || "no candidate model succeeded"}`, "error");
				return;
			}

			const text = sanitizeReply(raw);
			if (text.length === 0) {
				state = "failure";
				ctx.ui.notify(`deepen: ${wireModel(used.model)} returned an empty result — draft untouched`, "error");
				return;
			}
			if (ctx.ui.getEditorText() !== editorAtStart) {
				// 草稿被改：绝不覆盖。结果暂存，用户想要就显式取回。
				state = "draft-changed";
				pending = { text, style, model: used.model };
				ctx.ui.notify(`deepen: composer changed while running — result kept, ${RUN_KEY} or /deepen apply to take it`, "warning");
				return;
			}
			state = "success";
			pending = undefined;
			ctx.ui.setEditorText(text);
			const via = used === primary ? "" : " (fallback)";
			ctx.ui.notify(`✨ deepened (${style} · ${wireModel(used.model)}${via})`, "info");
		} finally {
			ctx.clearTimer(deadline);
			ctx.clearTimer(ticker);
			ctx.ui.setStatus(STATUS_KEY, undefined);
			if (inFlight === controller) inFlight = undefined;
			if (state === "running") state = "idle";
		}
	}

	/** 取回 `draft-changed` 暂存的结果。这是用户显式动作，所以允许覆盖当前输入框内容。 */
	function applyPending(ctx: ExtensionContext): void {
		if (state === "running") {
			ctx.ui.notify(`deepen: still running — ${CANCEL_KEY} or /deepen cancel stops it`, "warning");
			return;
		}
		if (!pending) {
			ctx.ui.notify("deepen: no kept result to apply", "warning");
			return;
		}
		ctx.ui.setEditorText(pending.text);
		ctx.ui.notify(`✨ applied kept result (${pending.style} · ${wireModel(pending.model)})`, "info");
		pending = undefined;
		state = "idle";
	}

	/** 取消入口。两个键位/命令都走这里，保证只有一处 abort 逻辑。 */
	function cancel(ctx: ExtensionContext): void {
		if (state !== "running" || !inFlight) {
			ctx.ui.notify("deepen: no request running", "warning");
			return;
		}
		inFlight.abort();
	}

	/** `/deepen config`：把生效配置和暂存状态摊开，避免用户去猜配置文件长什么样。 */
	function showConfig(ctx: ExtensionContext): void {
		const { config, rejected } = readConfig();
		const list = candidates(config);
		const lines = [
			`config: ${configPath()}`,
			`model: ${list[0]!.model}${list.length > 1 ? ` (fallback ${list[1]!.model})` : ""}`,
			`baseUrl: ${list[0]!.baseUrl}`,
			`apiKeyEnv: ${list[0]!.apiKeyEnv} (${process.env[list[0]!.apiKeyEnv] ? "set" : "MISSING"})`,
			`maxTokens: ${config.maxTokens ?? DEFAULT_MAX_TOKENS}`,
			`style: ${config.style ?? `${DEFAULT_STYLE} (default)`}`,
			`system: ${config.system ? "custom" : "builtin"}`,
			`state: ${state}${pending ? " (result kept)" : ""}`,
		];
		if (rejected.length > 0) lines.push(`ignored bad keys: ${rejected.join(", ")}`);
		ctx.ui.notify(lines.join("\n"), "info");
	}

	/** `/deepen style`：弹选择器并把选择持久化到配置文件。取消选择则什么都不写。 */
	async function chooseStyle(ctx: ExtensionCommandContext): Promise<void> {
		const label = await ctx.ui.select(
			"Deepen style (saved to deepen.json)",
			STYLES.map(style => ({ label: style, description: STYLE_DESCRIPTIONS[style] })),
			{ outline: true },
		);
		const style = normalizeStyle(label);
		if (!style) return;
		try {
			persistStyle(style);
			ctx.ui.notify(`deepen: default style is now ${style}`, "info");
		} catch (error) {
			ctx.ui.notify(`deepen: cannot write ${configPath()}: ${error instanceof Error ? error.message : String(error)}`, "error");
		}
	}

	// `/deepen [style] [text…] | cancel | apply | config | style`
	pi.registerCommand("deepen", {
		description: `Deepen a prompt: /deepen [deep|quick|spec] [text…], or /deepen {cancel|apply|config|style}`,
		getArgumentCompletions: prefix => {
			// 只在第一个 token 上补全；已经开始写提示词就不打扰。
			if (prefix.includes(" ")) return null;
			const lowered = prefix.trim().toLowerCase();
			const entries: Array<{ value: string; description: string }> = [
				{ value: "cancel", description: `Stop the running request (same as ${CANCEL_KEY})` },
				{ value: "apply", description: "Fill the composer with the kept result" },
				{ value: "config", description: "Show the effective config and state" },
				{ value: "style", description: "Pick the default style and save it" },
				...STYLES.map(style => ({ value: style, description: STYLE_DESCRIPTIONS[style] })),
			];
			const hits = entries
				.filter(entry => entry.value.startsWith(lowered))
				.map(entry => ({ value: entry.value, label: entry.value, description: entry.description }));
			return hits.length > 0 ? hits : null;
		},
		handler: async (args, ctx) => {
			const trimmed = args.trim();
			const [first, ...rest] = trimmed.split(/\s+/);
			const keyword = first?.toLowerCase();
			if (keyword === "cancel") return cancel(ctx);
			if (keyword === "apply") return applyPending(ctx);
			if (keyword === "config") return showConfig(ctx);
			if (keyword === "style") return chooseStyle(ctx);
			// 首个 token 是风格 → 剩下的是提示词；否则整串都是提示词，空串则回落到输入框。
			const style = normalizeStyle(first);
			const text = style ? rest.join(" ") : trimmed;
			return run(ctx, { style, explicitText: text.length > 0 ? text : undefined });
		},
	});

	// 运行键：空闲时加深输入框草稿；有暂存结果时改为取回（同一个键，语义跟着状态走）。
	pi.registerShortcut(RUN_KEY, {
		description: "Deepen the composer draft (or take the kept result)",
		handler: ctx => (pending && state !== "running" ? applyPending(ctx) : run(ctx, {})),
	});

	// 取消键：唯一 abort 入口的键位形态。
	pi.registerShortcut(CANCEL_KEY, {
		description: "Cancel the running deepen request",
		handler: ctx => cancel(ctx),
	});

	// 会话结束（切换/退出）时别让请求挂着：abort 后 fetch 立刻断，不会拖住进程退出。
	pi.on("session_shutdown", () => {
		inFlight?.abort();
	});
}

/**
 * 风格归一化：配置文件、select label、命令参数三处都要「去空白 + 转小写 + 查白名单」，
 * 写成一处免得三处规则漂移（类比 C++：同一个 enum 的解析只留一个 from_string）。
 */
function normalizeStyle(value: unknown): Style | undefined {
	if (typeof value !== "string") return undefined;
	const key = value.trim().toLowerCase();
	return (STYLES as readonly string[]).includes(key) ? (key as Style) : undefined;
}
