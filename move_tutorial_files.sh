#!/bin/bash

# Script to move all tutorial Swift files from ko.lproj to Resources

SOURCE_DIR="/Users/suhwonji/Desktop/SideProject/DiContainer/Sources/DiContainer.docc/ko.lproj"
DEST_DIR="/Users/suhwonji/Desktop/SideProject/DiContainer/Sources/DiContainer.docc/Resources"

echo "Moving tutorial Swift files from ko.lproj to Resources..."
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"

# Count files before moving
total_files=$(find "$SOURCE_DIR" -name "Tutorial-*.swift" | wc -l)
echo "Found $total_files tutorial Swift files to move"

# Move each file
moved_count=0
for file in "$SOURCE_DIR"/Tutorial-*.swift; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "Moving: $filename"
        mv "$file" "$DEST_DIR/$filename"
        if [ $? -eq 0 ]; then
            ((moved_count++))
        else
            echo "Error moving: $filename"
        fi
    fi
done

echo "Successfully moved $moved_count out of $total_files files"
echo "Verifying files in Resources directory..."
resources_count=$(find "$DEST_DIR" -name "Tutorial-*.swift" | wc -l)
echo "Files now in Resources: $resources_count"