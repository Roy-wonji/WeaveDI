#!/bin/bash

# Copy script for tutorial files
SRC_DIR="/Users/suhwonji/Desktop/SideProject/DiContainer/Sources/DiContainer.docc/ko.lproj"
DEST_DIR="/Users/suhwonji/Desktop/SideProject/DiContainer/Sources/DiContainer.docc/Resources"

echo "Copying tutorial files from ko.lproj to Resources..."

# Intermediate files
intermediate_files=(
    "Tutorial-IntermediateDiContainer-01-01.swift"
    "Tutorial-IntermediateDiContainer-01-02.swift"
    "Tutorial-IntermediateDiContainer-01-03.swift"
    "Tutorial-IntermediateDiContainer-02-01.swift"
    "Tutorial-IntermediateDiContainer-02-02.swift"
    "Tutorial-IntermediateDiContainer-03-01.swift"
    "Tutorial-IntermediateDiContainer-03-02.swift"
    "Tutorial-IntermediateDiContainer-04-01.swift"
    "Tutorial-IntermediateDiContainer-04-02.swift"
    "Tutorial-IntermediateDiContainer-05-01.swift"
    "Tutorial-IntermediateDiContainer-05-02.swift"
)

# Advanced files
advanced_files=(
    "Tutorial-AdvancedDiContainer-01-01.swift"
    "Tutorial-AdvancedDiContainer-01-02.swift"
    "Tutorial-AdvancedDiContainer-01-03.swift"
    "Tutorial-AdvancedDiContainer-02-01.swift"
    "Tutorial-AdvancedDiContainer-02-02.swift"
    "Tutorial-AdvancedDiContainer-02-03.swift"
    "Tutorial-AdvancedDiContainer-03-01.swift"
    "Tutorial-AdvancedDiContainer-03-02.swift"
    "Tutorial-AdvancedDiContainer-03-03.swift"
    "Tutorial-AdvancedDiContainer-04-01.swift"
    "Tutorial-AdvancedDiContainer-04-02.swift"
    "Tutorial-AdvancedDiContainer-04-03.swift"
    "Tutorial-AdvancedDiContainer-05-01.swift"
    "Tutorial-AdvancedDiContainer-05-02.swift"
    "Tutorial-AdvancedDiContainer-05-03.swift"
)

copied_count=0
error_count=0

echo "Copying Intermediate tutorial files..."
for file in "${intermediate_files[@]}"; do
    if [ -f "$SRC_DIR/$file" ]; then
        cp "$SRC_DIR/$file" "$DEST_DIR/$file"
        if [ $? -eq 0 ]; then
            echo "✓ Copied: $file"
            ((copied_count++))
        else
            echo "✗ Error copying: $file"
            ((error_count++))
        fi
    else
        echo "✗ Source not found: $file"
        ((error_count++))
    fi
done

echo "Copying Advanced tutorial files..."
for file in "${advanced_files[@]}"; do
    if [ -f "$SRC_DIR/$file" ]; then
        cp "$SRC_DIR/$file" "$DEST_DIR/$file"
        if [ $? -eq 0 ]; then
            echo "✓ Copied: $file"
            ((copied_count++))
        else
            echo "✗ Error copying: $file"
            ((error_count++))
        fi
    else
        echo "✗ Source not found: $file"
        ((error_count++))
    fi
done

echo "=================================================="
echo "COPY OPERATION COMPLETE"
echo "=================================================="
echo "Files copied: $copied_count"
echo "Errors: $error_count"
echo "Total processed: $((copied_count + error_count))"

# Verify files in Resources
echo ""
echo "Verifying files in Resources folder:"
ls -1 "$DEST_DIR"/Tutorial-*DiContainer-*.swift | wc -l | xargs echo "Total tutorial files in Resources:"