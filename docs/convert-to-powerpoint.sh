#!/bin/bash

# Script to convert Markdown presentation to PowerPoint
# Requires: pandoc and optionally LibreOffice

set -e

echo "=========================================="
echo "Convert Markdown to PowerPoint"
echo "=========================================="
echo ""

INPUT_FILE="docs/BOB_SECURE_DEVELOPMENT_PRESENTATION.md"
OUTPUT_FILE="docs/BOB_Secure_Development_Presentation.pptx"

# Check if pandoc is installed
if ! command -v pandoc &> /dev/null; then
    echo "Error: pandoc is not installed"
    echo ""
    echo "Install pandoc on macOS:"
    echo "  brew install pandoc"
    echo ""
    echo "Or download from: https://pandoc.org/installing.html"
    exit 1
fi

echo "Converting $INPUT_FILE to PowerPoint..."
echo ""

# Convert to PowerPoint
pandoc "$INPUT_FILE" \
    -o "$OUTPUT_FILE" \
    -t pptx \
    --slide-level=1

if [ -f "$OUTPUT_FILE" ]; then
    echo "✓ Conversion successful!"
    echo ""
    echo "Output file: $OUTPUT_FILE"
    echo ""
    echo "You can now:"
    echo "  1. Open in PowerPoint: open '$OUTPUT_FILE'"
    echo "  2. Open in Keynote: open -a Keynote '$OUTPUT_FILE'"
    echo "  3. Edit and customize the slides"
    echo ""
else
    echo "✗ Conversion failed"
    exit 1
fi

# Optional: Open the file
read -p "Do you want to open the PowerPoint file now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$OUTPUT_FILE"
fi

echo "Done!"

# Made with Bob
