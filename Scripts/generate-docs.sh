#!/bin/bash

# WeaveDI Documentation Generator
# Generates English and Korean documentation from Swift-DocC

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCC_DIR="$PROJECT_ROOT/Sources/WeaveDI.docc"
OUTPUT_DIR="$PROJECT_ROOT/docs"

echo "🚀 WeaveDI Documentation Generator"
echo "=================================="

# Create output directories
mkdir -p "$OUTPUT_DIR/ko/api"
mkdir -p "$OUTPUT_DIR/en/api"

# Function to convert DocC markdown to VitePress markdown
convert_docc_to_vitepress() {
    local input_file="$1"
    local output_file="$2"
    local lang="$3"

    echo "📝 Converting: $input_file -> $output_file"

    # Read the file
    content=$(cat "$input_file")

    # Add VitePress frontmatter
    cat > "$output_file" << EOF
---
title: $(basename "$input_file" .md | sed 's/-/ /g')
lang: $lang
---

$content
EOF
}

# Generate English docs
echo ""
echo "📚 Generating English documentation..."
if [ -d "$DOCC_DIR/en.lproj" ]; then
    find "$DOCC_DIR/en.lproj" -name "*.md" -type f | while read -r file; do
        filename=$(basename "$file")
        output_file="$OUTPUT_DIR/en/api/$filename"
        convert_docc_to_vitepress "$file" "$output_file" "en-US"
    done
    echo "✅ English docs generated"
else
    echo "⚠️  English docs directory not found"
fi

# Generate Korean docs
echo ""
echo "📚 Generating Korean documentation..."
if [ -d "$DOCC_DIR/ko.lproj" ]; then
    find "$DOCC_DIR/ko.lproj" -name "*.md" -type f | while read -r file; do
        filename=$(basename "$file")
        output_file="$OUTPUT_DIR/ko/api/$filename"
        convert_docc_to_vitepress "$file" "$output_file" "ko-KR"
    done
    echo "✅ Korean docs generated"
else
    echo "⚠️  Korean docs directory not found"
fi

# Generate API reference from Swift source
echo ""
echo "🔧 Generating API reference..."

# Parse Swift files and generate markdown
generate_api_docs() {
    local source_dir="$1"
    local output_dir="$2"
    local lang="$3"

    # Find all public structs, classes, and protocols
    find "$source_dir" -name "*.swift" -type f | while read -r swift_file; do
        # Extract public declarations
        filename=$(basename "$swift_file" .swift)

        # Skip if not a public API file
        if ! grep -q "^public" "$swift_file" 2>/dev/null; then
            continue
        fi

        echo "  📄 Processing: $filename"

        # Generate markdown from Swift comments
        output_md="$output_dir/${filename}.md"

        {
            echo "---"
            echo "title: $filename"
            echo "lang: $lang"
            echo "---"
            echo ""
            echo "# $filename"
            echo ""

            # Extract documentation comments
            awk '
                /\/\/\/ / {
                    gsub(/^\/\/\/ /, "");
                    in_doc = 1;
                    print;
                }
                /^public/ && in_doc {
                    print "";
                    print "```swift";
                    print;
                    getline;
                    while ($0 !~ /^}$/ && NF > 0) {
                        print;
                        if (getline <= 0) break;
                    }
                    print "}";
                    print "```";
                    print "";
                    in_doc = 0;
                }
            ' "$swift_file"
        } > "$output_md"
    done
}

# Generate English API reference
echo "  🇺🇸 English API..."
generate_api_docs "$PROJECT_ROOT/Sources" "$OUTPUT_DIR/en/api" "en-US"

# Generate Korean API reference
echo "  🇰🇷 Korean API..."
generate_api_docs "$PROJECT_ROOT/Sources" "$OUTPUT_DIR/ko/api" "ko-KR"

echo ""
echo "✅ Documentation generation complete!"
echo ""
echo "📂 Output directories:"
echo "   English: $OUTPUT_DIR/en/api"
echo "   Korean:  $OUTPUT_DIR/ko/api"
echo ""
echo "💡 Next steps:"
echo "   1. Review generated markdown files"
echo "   2. Run 'npm run docs:dev' to preview"
echo "   3. Run 'npm run docs:build' to build static site"