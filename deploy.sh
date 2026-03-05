#!/bin/bash
# Iran War Tracker 部署脚本

echo "🚀 开始部署 Iran War Tracker..."

# 检查 GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "❌ 请先安装 GitHub CLI: brew install gh"
    exit 1
fi

# 检查登录状态
if ! gh auth status &> /dev/null; then
    echo "❌ 请先登录 GitHub: gh auth login"
    exit 1
fi

# 创建仓库
REPO_NAME="iran-war-tracker"
echo "📦 创建 GitHub 仓库: $REPO_NAME..."

cd ~/.openclaw/workspace/iran-war-tracker

# 初始化 git
git init
git add .
git commit -m "Initial commit"

# 创建 GitHub 仓库并推送
gh repo create $REPO_NAME --public --source=. --push

# 启用 GitHub Pages
echo "📄 启用 GitHub Pages..."
gh api repos/{owner}/$REPO_NAME/pages \
  --method POST \
  --input -<<EOF
{
  "source": {
    "branch": "main",
    "path": "/"
  }
}
EOF

echo "✅ 部署完成！"
echo ""
echo "🌐 网站地址: https://$(gh api user -q .login).github.io/$REPO_NAME"
echo ""
echo "⚠️  注意：首次部署可能需要 5-10 分钟生效"
echo "📱 添加 GitHub Secrets 实现自动更新:"
echo "   1. 访问 https://github.com/$(gh api user -q .login)/$REPO_NAME/settings/secrets/actions"
echo "   2. 添加 TAVILY_API_KEY 密钥"
echo "   3. 网站将每 30 分钟自动更新新闻"