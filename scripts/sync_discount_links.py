#!/usr/bin/env python3
"""Sync shared discount links into the iOS and Android app source files."""

from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "shared" / "discount_links.json"
IOS_FILE = ROOT / "KWh Gas Companion" / "DiscountsView.swift"
ANDROID_FILE = ROOT / "MyEVCompanion-Android" / "app" / "src" / "main" / "java" / "com" / "myevcompanion" / "app" / "ui" / "screens" / "ToolDetailScreen.kt"

BEGIN = "// BEGIN SHARED DISCOUNT LINKS"
END = "// END SHARED DISCOUNT LINKS"

CATEGORY_CASES = {
    "Referrals": "referrals",
    "Accessories": "accessories",
}


def load_links() -> list[dict[str, str]]:
    links = json.loads(SOURCE.read_text(encoding="utf-8"))
    if not isinstance(links, list):
        raise ValueError(f"{SOURCE} must contain a JSON array")

    for index, link in enumerate(links, start=1):
        if not isinstance(link, dict):
            raise ValueError(f"Discount link #{index} must be an object")

        for field in ("name", "url", "category", "symbol"):
            value = link.get(field)
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"Discount link #{index} is missing a non-empty {field!r}")

        if link["category"] not in CATEGORY_CASES:
            allowed = ", ".join(CATEGORY_CASES)
            raise ValueError(f"Discount link #{index} has category {link['category']!r}; expected one of: {allowed}")

        parsed = urlparse(link["url"])
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise ValueError(f"Discount link #{index} has an invalid absolute URL: {link['url']!r}")

    return links


def swift_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def kotlin_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def replace_marked_block(path: Path, generated_lines: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    begin_index = next((i for i, line in enumerate(lines) if BEGIN in line), None)
    end_index = next((i for i, line in enumerate(lines) if END in line), None)
    if begin_index is None or end_index is None or begin_index >= end_index:
        raise ValueError(f"{path} is missing a valid shared discount links marker block")

    updated = lines[: begin_index + 1] + generated_lines + lines[end_index:]
    path.write_text("\n".join(updated) + "\n", encoding="utf-8")


def sync_ios(links: list[dict[str, str]]) -> None:
    generated = []
    for link in links:
        category_case = CATEGORY_CASES[link["category"]]
        generated.append(
            f"        add({swift_string(link['name'])}, {swift_string(link['url'])}, .{category_case}, {swift_string(link['symbol'])})"
        )
    replace_marked_block(IOS_FILE, generated)


def sync_android(links: list[dict[str, str]]) -> None:
    generated = []
    for index, link in enumerate(links):
        suffix = "," if index < len(links) - 1 else ""
        generated.append(
            f"    DiscountLinkItem({kotlin_string(link['name'])}, {kotlin_string(link['url'])}, {kotlin_string(link['category'])}){suffix}"
        )
    replace_marked_block(ANDROID_FILE, generated)


def main() -> None:
    links = load_links()
    sync_ios(links)
    sync_android(links)
    print(f"Synced {len(links)} discount links from {SOURCE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
