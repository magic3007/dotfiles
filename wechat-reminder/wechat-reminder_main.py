#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# File              : wechat-reminder_main.py
# Author            : Jing Mai <jingmai@pku.edu.cn>
# Date              : 05.25.2022
# Last Modified Date: 2026-04-15
# Last Modified By  : Jing Mai <jingmai@pku.edu.cn>

import os
import argparse
import requests
import socket
import re


def parse_content_segments(text):
    """Split text into alternating text and table segments.

    Returns a list of dicts:
      {"type": "text", "content": "..."}
      {"type": "table", "headers": [...], "rows": [[...], ...]}
    """
    if not text:
        return [{"type": "text", "content": text or ""}]

    lines = text.split('\n')
    segments = []
    current_text_lines = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # Check if this could be a table header row
        if line.strip().startswith('|') and i + 1 < len(lines):
            separator = lines[i + 1].strip()

            # Separator pattern: |---|---| with optional : alignment markers
            if re.match(
                r'^\|[\s:]*-{2,}[\s:]*(\|[\s:]*-{2,}[\s:]*)*\|?\s*$',
                separator
            ):
                # Parse header cells
                headers = [
                    cell.strip()
                    for cell in line.strip().strip('|').split('|')
                ]

                # Move past header + separator
                table_start_line = i
                i += 2

                # Collect data rows
                rows = []
                while i < len(lines) and lines[i].strip().startswith('|'):
                    row_cells = [
                        cell.strip()
                        for cell in lines[i].strip().strip('|').split('|')
                    ]
                    rows.append(row_cells)
                    i += 1

                if rows:
                    # Flush accumulated text
                    if current_text_lines:
                        segments.append({
                            "type": "text",
                            "content": '\n'.join(current_text_lines)
                        })
                        current_text_lines = []

                    segments.append({
                        "type": "table",
                        "headers": headers,
                        "rows": rows
                    })
                else:
                    # No data rows — degrade to plain text
                    current_text_lines.append(lines[table_start_line])
                    current_text_lines.append(lines[table_start_line + 1])

                continue

        current_text_lines.append(line)
        i += 1

    if current_text_lines:
        segments.append({
            "type": "text",
            "content": '\n'.join(current_text_lines)
        })

    return segments


def build_feishu_table(segment):
    """Convert a parsed table segment to a Feishu native table card element."""
    columns = []
    for idx, header in enumerate(segment["headers"]):
        columns.append({
            "name": f"col_{idx}",
            "display_name": header,
            "data_type": "lark_md",
            "width": "auto"
        })

    rows = []
    for row in segment["rows"]:
        row_dict = {}
        for idx, cell in enumerate(row):
            if idx < len(segment["headers"]):
                row_dict[f"col_{idx}"] = cell
        rows.append(row_dict)

    return {
        "tag": "table",
        "page_size": 10,
        "row_height": "low",
        "header_style": {
            "text_align": "left",
            "background_style": "grey",
            "bold": True
        },
        "columns": columns,
        "rows": rows
    }


def table_to_text_fallback(segment):
    """Convert a table segment back to plain text (fallback when >5 tables)."""
    lines = []
    headers = segment["headers"]
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
    for row in segment["rows"]:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


# Get environment variables
PUSHDEER_KEY = os.environ.get("PUSHDEER_KEY")
FEISHU_WEBHOOK_URL = os.environ.get("FEISHU_WEBHOOK_URL")


def send_to_feishu(webhook_url, title, desp, color="green"):
    """Send message to Feishu via webhook using interactive card.

    Parses desp for Markdown tables and renders them as native Feishu
    table elements. Non-table text is rendered as lark_md divs.
    """
    payload = {
        "msg_type": "interactive",
        "card": {
            "config": {
                "wide_screen_mode": True,
                "enable_forward": True
            },
            "header": {
                "title": {
                    "tag": "plain_text",
                    "content": title
                },
                "template": color
            },
            "elements": []
        }
    }

    if desp:
        segments = parse_content_segments(desp)
        table_count = 0
        for segment in segments:
            if segment["type"] == "text" and segment["content"].strip():
                payload["card"]["elements"].append({
                    "tag": "div",
                    "text": {
                        "tag": "lark_md",
                        "content": segment["content"]
                    }
                })
            elif segment["type"] == "table":
                if table_count < 5:
                    payload["card"]["elements"].append(
                        build_feishu_table(segment)
                    )
                    table_count += 1
                else:
                    payload["card"]["elements"].append({
                        "tag": "div",
                        "text": {
                            "tag": "lark_md",
                            "content": table_to_text_fallback(segment)
                        }
                    })

    try:
        response = requests.post(webhook_url, json=payload, timeout=10)
        response.raise_for_status()
    except Exception as e:
        print(f"Failed to send to Feishu ({webhook_url}): {e}")


def main(args):
    # Add hostname to title
    try:
        hostname = socket.gethostname()
        args.title = f"[{hostname}] {args.title}"
    except Exception:
        pass  # Keep original title if hostname cannot be obtained

    # Send to WeChat if PUSHDEER_KEY is set and not empty
    if PUSHDEER_KEY:
        try:
            from pypushdeer import PushDeer

            for key in PUSHDEER_KEY.split(","):
                key = key.strip()
                if not key:
                    continue
                pushdeer = PushDeer(pushkey=key)
                pushdeer.send_text(args.title, desp=args.desp)
        except ImportError:
            print("Warning: pypushdeer not installed. WeChat notifications disabled.")

    # Send to Feishu if FEISHU_WEBHOOK_URL is set and not empty
    if FEISHU_WEBHOOK_URL:
        for url in FEISHU_WEBHOOK_URL.split(","):
            url = url.strip()
            if not url:
                continue
            send_to_feishu(url, args.title, args.desp, args.color)


if __name__ == "__main__":
    # Clean and validate environment variables
    if PUSHDEER_KEY is not None:
        PUSHDEER_KEY = PUSHDEER_KEY.strip()
    if FEISHU_WEBHOOK_URL is not None:
        FEISHU_WEBHOOK_URL = FEISHU_WEBHOOK_URL.strip()

    if (PUSHDEER_KEY is None or not PUSHDEER_KEY) and (FEISHU_WEBHOOK_URL is None or not FEISHU_WEBHOOK_URL):
        raise Exception("Environment variable PUSHDEER_KEY or FEISHU_WEBHOOK_URL must be set")
    parser = argparse.ArgumentParser(description="Send a message to WeChat or Feishu.")
    parser.add_argument(
        "--title", type=str, default="Notification", help="Title of the message."
    )
    parser.add_argument(
        "--desp", type=str, default="", help="Description of the message (supports lark_md for Feishu)."
    )
    parser.add_argument(
        "--color", type=str, default="green",
        choices=["blue", "wathet", "turquoise", "green", "yellow", "orange", "red", "carmine", "violet", "purple", "indigo", "grey", "default"],
        help="Header color template for Feishu card."
    )
    args = parser.parse_args()
    main(args)
