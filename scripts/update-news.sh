#!/bin/bash
# Iran War Tracker - 自动新闻更新脚本
# 每30分钟运行一次，抓取最新新闻并更新网站

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/update.log"
DATA_FILE="$PROJECT_DIR/data/news-data.json"
HTML_FILE="$PROJECT_DIR/index.html"

# API Keys
TAVILY_API_KEY="${TAVILY_API_KEY:-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}"

# 确保目录存在
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/data"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "开始更新新闻数据..."

# 使用 Tavily API 抓取新闻
RESPONSE=$(curl -s -X POST "https://api.tavily.com/search" \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API_KEY\",
        \"query\": \"Iran Israel war conflict latest news today\",
        \"topic\": \"news\",
        \"days\": 1,
        \"max_results\": 15,
        \"include_answer\": true,
        \"search_depth\": \"advanced\"
    }" 2>/dev/null || echo '{"results": []}')

# 检查是否有结果
if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]; then
    log "❌ API 返回空数据"
    exit 1
fi

# 保存原始数据
echo "$RESPONSE" > "$DATA_FILE"

# 解析并生成新闻数据
NEWS_JSON=$(echo "$RESPONSE" | python3 << 'EOF'
import json
import sys
from datetime import datetime

try:
    data = json.load(sys.stdin)
    results = data.get('results', [])
    
    news_items = []
    for i, item in enumerate(results[:15], 1):
        news_items.append({
            "id": i,
            "time": datetime.now().strftime("%Y-%m-%d %H:%M"),
            "title": item.get('title', 'No title'),
            "content": (item.get('content', '')[:200] + '...') if item.get('content') else 'No content',
            "source": item.get('source', 'Unknown'),
            "sourceUrl": item.get('url', '#'),
            "tags": ["military"] if any(kw in item.get('title', '').lower() for kw in ['attack', 'strike', 'missile', 'war']) else ["diplomacy"],
            "urgent": any(kw in item.get('title', '').lower() for kw in ['attack', 'strike', 'kill', 'destroy'])
        })
    
    print(json.dumps(news_items, indent=2, ensure_ascii=False))
except Exception as e:
    print('[]')
    sys.stderr.write(f"Error: {e}\n")
EOF
)

# 更新 HTML 文件
python3 << EOF
import json
import re

# 读取新闻数据
news_data = json.loads('''$NEWS_JSON''')

# 读取 HTML
with open('$HTML_FILE', 'r', encoding='utf-8') as f:
    html = f.read()

# 替换新闻数据
news_data_str = json.dumps(news_data, indent=4, ensure_ascii=False)

# 使用正则替换 newsData
pattern = r'const newsData = \[.*?\];'
replacement = f'const newsData = {news_data_str};'
new_html = re.sub(pattern, replacement, html, flags=re.DOTALL)

# 更新时间
from datetime import datetime
time_str = datetime.now().strftime("%Y-%m-%d %H:%M")
new_html = new_html.replace(
    'id="last-update"',
    f'id="last-update"'
)
new_html = re.sub(
    r'id="last-update"\u003e.*?\u003c/span\u003e',
    f'id="last-update"\u003e{time_str} (GMT+8)\u003c/span\u003e',
    new_html
)

# 保存
with open('$HTML_FILE', 'w', encoding='utf-8') as f:
    f.write(new_html)

print(f"✅ 更新了 {len(news_data)} 条新闻")
EOF

log "✅ 新闻更新完成: $(echo '$NEWS_JSON' | grep -c 'id') 条"

# 提交到 Git（如果在 Git 仓库中）
if [ -d "$PROJECT_DIR/.git" ]; then
    cd "$PROJECT_DIR"
    git add index.html data/news-data.json
    git diff --quiet && git diff --staged --quiet || {
        git commit -m "Auto-update: $(date '+%Y-%m-%d %H:%M')"
        git push origin main 2>/dev/null || log "⚠️ Git push 失败"
    }
fi

log "✅ 更新流程完成"