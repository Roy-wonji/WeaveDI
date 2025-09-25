#!/usr/bin/env python3

import os
import shutil
from pathlib import Path

def move_tutorial_files():
    """Move all Swift tutorial files to Resources folder"""

    source_dir = Path("/Users/suhwonji/Desktop/SideProject/DiContainer/Sources/DiContainer.docc/ko.lproj")
    target_dir = Path("/Users/suhwonji/Desktop/SideProject/DiContainer/Sources/DiContainer.docc/Resources")

    # Ensure target directory exists
    target_dir.mkdir(exist_ok=True)

    # Find all Swift files
    swift_files = list(source_dir.glob("*.swift"))

    moved_files = []
    skipped_files = []

    print(f"Found {len(swift_files)} Swift files to process")

    for swift_file in swift_files:
        target_file = target_dir / swift_file.name

        # Skip if already exists
        if target_file.exists():
            skipped_files.append(swift_file.name)
            continue

        try:
            # Copy the file (keeping original for safety)
            shutil.copy2(swift_file, target_file)
            moved_files.append(swift_file.name)
            print(f"✓ Copied: {swift_file.name}")
        except Exception as e:
            print(f"✗ Failed to copy {swift_file.name}: {e}")

    print(f"\nSummary:")
    print(f"- Files copied: {len(moved_files)}")
    print(f"- Files skipped (already exist): {len(skipped_files)}")

    return moved_files, skipped_files

if __name__ == "__main__":
    move_tutorial_files()