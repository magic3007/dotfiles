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


# Get environment variables
PUSHDEER_KEY = os.environ.get("PUSHDEER_KEY")
FEISHU_WEBHOOK_URL = os.environ.get("FEISHU_WEBHOOK_URL")


def send_to_feishu(webhook_url, title, desp, color="green"):
    """Send message to Feishu via webhook using interactive card with lark_md."""
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
        payload["card"]["elements"].append({
            "tag": "div",
            "text": {
                "tag": "lark_md",
                "content": desp
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
