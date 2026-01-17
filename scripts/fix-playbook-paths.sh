#!/bin/bash
# scripts/fix-playbook-paths.sh
# Fix all playbook paths to use {{ repo_root }} instead of {{ playbook_dir }}

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

echo "🔧 Fixing playbook paths to use {{ repo_root }} variable..."
echo ""

# Find all YAML files in playbooks directory
find "$REPO_ROOT/playbooks" -name "*.yml" -type f | while read -r file; do
    echo "Processing: ${file#$REPO_ROOT/}"
    
    # Replace {{ playbook_dir }}/tasks with {{ repo_root }}/tasks
    sed -i '' 's|{{ playbook_dir }}/tasks|{{ repo_root }}/tasks|g' "$file"
    
    # Replace {{ playbook_dir }}/.. with {{ repo_root }}
    sed -i '' 's|{{ playbook_dir }}/\.\.|{{ repo_root }}|g' "$file"
done

echo ""
echo "✅ All playbooks updated!"
echo ""
echo "Summary of changes:"
echo "  - {{ playbook_dir }}/tasks → {{ repo_root }}/tasks"
echo "  - {{ playbook_dir }}/.. → {{ repo_root }}"
echo ""
echo "Next steps:"
echo "  1. Review changes with: git diff"
echo "  2. Test a playbook: ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit personal --check"