#!/usr/bin/env python3

import base64
import tarfile
import tempfile
from pathlib import Path


PATCH_PAYLOAD = Path("BuildPatches/guided-casebook-sources.tar.gz.b64")


def restore_guided_casebook_sources() -> bool:
    if not PATCH_PAYLOAD.exists():
        return False

    with tempfile.TemporaryDirectory() as temp_dir:
        archive_path = Path(temp_dir) / "guided-casebook-sources.tar.gz"
        archive_path.write_bytes(base64.b64decode(PATCH_PAYLOAD.read_text()))
        with tarfile.open(archive_path, "r:gz") as archive:
            archive.extractall(".")

    return True


def replace_once(text: str, old: str, new: str, label: str, required: bool = True) -> str:
    if old in text:
        return text.replace(old, new, 1)
    if new in text:
        return text
    if not required:
        return text
    raise SystemExit(f"Expected pattern for {label!r} was not found.")


def main() -> None:
    restored_sources = restore_guided_casebook_sources()

    if not restored_sources:
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
                    title: "Preparing the first cases",
                    subtitle: "The Loophole Finder and Overreach Finder are assembling examples for you to review."
                )
            if session.cases.isEmpty {""",
            """                StatusCallout(
                    title: "Preparing the first cases",
                    subtitle: "The Loophole Finder and Overreach Finder are assembling examples for you to review."
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
        required=False,
    )
    loophole_client_path.write_text(loophole_client)


if __name__ == "__main__":
    main()
