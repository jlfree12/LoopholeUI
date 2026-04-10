#!/usr/bin/env python3

from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"Expected pattern for {label!r} was not found.")
    return text.replace(old, new, 1)


def main() -> None:
    content_view_path = Path("Sources/LoopholeUI/ContentView.swift")
    content_view = content_view_path.read_text()
    content_view = replace_once(
        content_view,
        "ViewThatFit(in: .horizontal) {",
        "ViewThatFits(in: .horizontal) {",
        "ViewThatFits fix",
    )
    content_view = replace_once(
        content_view,
        """                StatusCallout(
                    title: \"Preparing the first cases\",
                    subtitle: \"The Loophole Finder and Overreach Finder are assembling examples for you to review.\"
                )
            if session.cases.isEmpty {""",
        """                StatusCallout(
                    title: \"Preparing the first cases\",
                    subtitle: \"The Loophole Finder and Overreach Finder are assembling examples for you to review.\"
                )
            }
            if session.cases.isEmpty {""",
        "cases panel brace fix",
    )
    content_view_path.write_text(content_view)

    loophole_client_path = Path("Sources/LoopholeUI/LoopholeClient.swift")
    loophole_client = loophole_client_path.read_text()
    loophole_client = replace_once(
        loophole_client,
        "async throws -> LegalCodd {",
        "async throws -> LegalCode {",
        "DemoClient return type fix",
    )
    loophole_client_path.write_text(loophole_client)


if __name__ == "__main__":
    main()
