#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="evidence.txt"

mkdir -p site ec2 lambda iam

cat > "$OUTPUT_FILE" <<'EOF'
Cloud Evidence Collection
========================

Collected evidence for AWS environment review.

Structure:
- site/
- ec2/
- lambda/
- iam/

This file is intentionally created as a placeholder for evidence output.
EOF

printf 'Evidence collection initialized. Output: %s\n' "$OUTPUT_FILE"
