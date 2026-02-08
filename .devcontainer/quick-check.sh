#!/bin/bash
# Quick validation check - one-liner version
echo "🔍 Quick dev container validation..."
echo "Rust: $(rustc --version 2>/dev/null || echo '❌ Not found')"
echo ".NET: $(dotnet --version 2>/dev/null || echo '❌ Not found')"
echo "Docker: $(docker --version 2>/dev/null || echo '❌ Not found')"
echo "Azure CLI: $(az --version 2>/dev/null | head -n1 || echo '❌ Not found')"
echo "kubectl: $(kubectl version --client --short 2>/dev/null || echo '❌ Not found')"
echo ""
if [[ -d "src/rust-api" && -d "src/csharp-api" ]]; then
    echo "✅ Project structure looks good"
else
    echo "❌ Project structure issue - missing src directories"
fi
echo ""
echo "For detailed validation, run: .devcontainer/validate.sh"