/**
 * Pi Agent 任务完成通知扩展
 *
 * 监听 agent_settled 事件，在 Pi Agent 任务完成后通过 wechat-reminder
 * 发送飞书/微信通知（与 Claude Code 的 claude-end-reminder.sh 功能对应）。
 *
 * 依赖：
 *   - ~/.local/bin/wechat-reminder 二进制（来自 dotfiles wechat-reminder 包）
 *   - 环境变量 FEISHU_WEBHOOK_URL 或 PUSHDEER_KEY
 *
 * 开关：环境变量 END_REMINDER_ENABLE（默认关闭）。
 *   未设置 / 空 / 0 / false / no  -> 不发送通知
 *   设置为 1（或任意非零真值，如 yes/true/on）-> 发送通知
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { hostname } from "node:os";
import { appendFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const LOG_DIR = join(process.env.HOME || "/tmp", ".pi", "logs");
const LOG_FILE = join(LOG_DIR, "pi-end-reminder.log");
const WECHAT_BIN = join(process.env.HOME || "/tmp", ".local", "bin", "wechat-reminder");

function log(msg: string) {
  try {
    mkdirSync(LOG_DIR, { recursive: true });
    appendFileSync(LOG_FILE, msg + "\n", "utf-8");
  } catch {
    // silent
  }
}

function getGitInfo(cwd: string) {
  const info = { branch: "", repo: "", commit: "" };
  const opts = {
    cwd,
    encoding: "utf-8" as const,
    timeout: 3000,
    stdio: ["ignore", "pipe", "ignore"] as const,
  };
  try {
    info.branch = execFileSync("git", ["branch", "--show-current"], opts).trim();
  } catch {
    // not a git repo or git unavailable
  }
  try {
    info.repo =
      execFileSync("git", ["rev-parse", "--show-toplevel"], opts)
        .trim()
        .split("/")
        .pop() || "";
  } catch {
    // ignore
  }
  try {
    info.commit = execFileSync("git", ["log", "-1", "--format=%s"], opts)
      .trim()
      .slice(0, 60);
  } catch {
    // ignore
  }
  return info;
}

function getLastAssistantReply(entries: any[]): string {
  for (let i = entries.length - 1; i >= 0; i--) {
    const entry = entries[i];
    if (entry?.type === "message" && entry.message?.role === "assistant") {
      const content = entry.message.content;
      if (Array.isArray(content)) {
        const texts = content
          .filter((c: any) => c.type === "text")
          .map((c: any) => c.text);
        if (texts.length > 0) {
          return texts.join("\n");
        }
      }
      break;
    }
  }
  return "";
}

// 开关守卫：默认关闭，仅当 END_REMINDER_ENABLE 为非零真值时启用
function isEnabled(): boolean {
  const v = process.env.END_REMINDER_ENABLE || "";
  if (!v) return false;
  if (/^(0|false|no|off)$/i.test(v.trim())) return false;
  return true;
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async (_event, ctx) => {
    if (!isEnabled()) return; // 默认关闭，未启用则直接跳过
    const cwd = ctx.cwd;
    const projectDir = cwd;
    const projectName = projectDir.split("/").pop() || "unknown";

    // Git info
    const git = getGitInfo(cwd);

    // Host / user / time
    const host = hostname();
    const user = process.env.USER || "unknown";
    const now = new Date();
    const timestamp = now.toLocaleString("zh-CN", {
      timeZone: "Asia/Shanghai",
    });

    // Session ID
    const sessionFile = ctx.sessionManager.getSessionFile();
    const sessionId = sessionFile
      ? sessionFile.split("/").pop()?.replace(/\.jsonl$/, "") || ""
      : "";

    // 从 session 中获取最后一条 assistant 回复
    let lastReply = "";
    try {
      const entries = ctx.sessionManager.getEntries();
      lastReply = getLastAssistantReply(entries);
    } catch {
      // sessionManager might not be available in all contexts
    }

    // 构建 lark_md 格式的消息体（使用真实换行符）
    const lines: string[] = [];
    lines.push(`**项目**: ${git.repo || projectName}`);
    lines.push(`**目录**: ${projectDir}`);
    if (git.branch) lines.push(`**分支**: ${git.branch}`);
    if (git.commit) lines.push(`**最近提交**: ${git.commit}`);
    if (sessionId) lines.push(`**Session**: ${sessionId}`);
    lines.push(`**用户**: ${user}@${host}`);
    lines.push(`**完成时间**: ${timestamp}`);

    if (lastReply) {
      lines.push(`\n---`);
      lines.push(`**Pi 回复**:`);
      lines.push(lastReply);
    }

    const desp = lines.join("\n");

    // 调用 wechat-reminder 发送通知
    try {
      const result = execFileSync(
        WECHAT_BIN,
        [
          "--title",
          "Pi Agent 任务完成",
          "--desp",
          desp,
          "--color",
          "green",
        ],
        { timeout: 10000, encoding: "utf-8" }
      );
      log(
        `[${timestamp}] dir=${projectDir} branch=${git.branch} repo=${git.repo} commit=${git.commit} success feishu=${process.env.FEISHU_WEBHOOK_URL ? "yes" : "no"} pushdeer=${process.env.PUSHDEER_KEY ? "yes" : "no"} result=${result.trim()}`
      );
    } catch (err: any) {
      log(
        `[${timestamp}] dir=${projectDir} error=${err.message || err}`
      );
    }
  });
}