#!/usr/bin/env python3
"""
Script to copy Intermediate and Advanced tutorial Swift files to Resources folder
"""

import os
import shutil
import glob

def copy_tutorial_files():
    source_dir = "/Users/suhwonji/Desktop/SideProject/WeaveDI/Sources/WeaveDI.docc/ko.lproj"
    dest_dir = "/Users/suhwonji/Desktop/SideProject/WeaveDI/Sources/WeaveDI.docc/Resources"

    # Intermediate tutorial files
    intermediate_files = [
        "Tutorial-IntermediateWeaveDI-01-01.swift",
        "Tutorial-IntermediateWeaveDI-01-02.swift",
        "Tutorial-IntermediateWeaveDI-01-03.swift",
        "Tutorial-IntermediateWeaveDI-02-01.swift",
        "Tutorial-IntermediateWeaveDI-02-02.swift",
        "Tutorial-IntermediateWeaveDI-03-01.swift",
        "Tutorial-IntermediateWeaveDI-03-02.swift",
        "Tutorial-IntermediateWeaveDI-04-01.swift",
        "Tutorial-IntermediateWeaveDI-04-02.swift",
        "Tutorial-IntermediateWeaveDI-05-01.swift",
        "Tutorial-IntermediateWeaveDI-05-02.swift"
    ]

    # Advanced tutorial files
    advanced_files = [
        "Tutorial-AdvancedWeaveDI-01-01.swift",
        "Tutorial-AdvancedWeaveDI-01-02.swift",
        "Tutorial-AdvancedWeaveDI-01-03.swift",
        "Tutorial-AdvancedWeaveDI-02-01.swift",
        "Tutorial-AdvancedWeaveDI-02-02.swift",
        "Tutorial-AdvancedWeaveDI-02-03.swift",
        "Tutorial-AdvancedWeaveDI-03-01.swift",
        "Tutorial-AdvancedWeaveDI-03-02.swift",
        "Tutorial-AdvancedWeaveDI-03-03.swift",
        "Tutorial-AdvancedWeaveDI-04-01.swift",
        "Tutorial-AdvancedWeaveDI-04-02.swift",
        "Tutorial-AdvancedWeaveDI-04-03.swift",
        "Tutorial-AdvancedWeaveDI-05-01.swift",
        "Tutorial-AdvancedWeaveDI-05-02.swift",
        "Tutorial-AdvancedWeaveDI-05-03.swift"
    ]

    all_files = intermediate_files + advanced_files
    copied_count = 0
    skipped_count = 0
    error_count = 0

    print(f"Starting copy operation...")
    print(f"Source: {source_dir}")
    print(f"Destination: {dest_dir}")
    print(f"Total files to copy: {len(all_files)}")
    print()

    for filename in all_files:
        source_path = os.path.join(source_dir, filename)
        dest_path = os.path.join(dest_dir, filename)

        try:
            if os.path.exists(source_path):
                shutil.copy2(source_path, dest_path)
                print(f"✓ Copied: {filename}")
                copied_count += 1
            else:
                print(f"✗ Source not found: {filename}")
                error_count += 1

        except Exception as e:
            print(f"✗ Error copying {filename}: {e}")
            error_count += 1

    print()
    print("=" * 50)
    print("COPY OPERATION SUMMARY")
    print("=" * 50)
    print(f"Total files processed: {len(all_files)}")
    print(f"Successfully copied: {copied_count}")
    print(f"Skipped: {skipped_count}")
    print(f"Errors: {error_count}")
    print()

    # Verify copied files
    print("Verifying copied files in Resources:")
    resources_files = glob.glob(os.path.join(dest_dir, "Tutorial-*WeaveDI-*.swift"))
    intermediate_in_resources = [f for f in resources_files if "IntermediateWeaveDI" in f]
    advanced_in_resources = [f for f in resources_files if "AdvancedWeaveDI" in f]

    print(f"Intermediate tutorial files in Resources: {len(intermediate_in_resources)}/11")
    print(f"Advanced tutorial files in Resources: {len(advanced_in_resources)}/15")

    if copied_count == len(all_files):
        print("🎉 All tutorial files successfully copied to Resources folder!")
    else:
        print(f"⚠️  {len(all_files) - copied_count} files were not copied")

    return copied_count, error_count

if __name__ == "__main__":
    copy_tutorial_files()