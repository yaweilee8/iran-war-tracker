#!/bin/bash
# Iran War Tracker - 自动新闻更新脚本
set -e

PROJECT_DIR="/Users/yawei/.openclaw/workspace/iran-war-tracker"
LOG_FILE="$PROJECT_DIR/logs/update.log"
HTML_FILE="$PROJECT_DIR/index.html"
TAVILY_API_KEY="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"

mkdir -p "$PROJECT_DIR/logs"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始更新..." >> "$LOG_FILE"

# 抓取新闻
RESPONSE=$(curl -s -X POST "https://api.tavily.com/search" \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API_KEY\",
        \"query\": \"Iran Israel war conflict latest news\",
        \"topic\": \"news\",
        \"days\": 1,
        \"max_results\": 10,
        \"search_depth\": \"basic\"
    }")

# 保存响应到临时文件
RESPONSE_FILE=$(mktemp)
echo "$RESPONSE" > "$RESPONSE_FILE"

# 使用 Python 更新 HTML
python3 - "$RESPONSE_FILE" "$HTML_FILE" << 'PYSCRIPT'
import json
import re
import sys
from datetime import datetime
from urllib.parse import urlparse

def extract_source(url):
    """从 URL 提取域名作为来源"""
    try:
        domain = urlparse(url).netloc
        # 移除 www. 前缀
        if domain.startswith('www.'):
            domain = domain[4:]
        # 移除 .com 等后缀，只保留主名
        parts = domain.split('.')
        if len(parts) >= 2:
            return parts[0].capitalize()
        return domain.capitalize()
    except:
        return 'Unknown'

response_file = sys.argv[1]
html_file = sys.argv[2]

try:
    with open(response_file, 'r') as f:
        data = json.load(f)
    
    results = data.get('results', [])
    
    news_items = []
    for i, item in enumerate(results[:10], 1):
        title = item.get('title', 'No title')
        content = item.get('content', '')[:180] + '...' if item.get('content') else 'No content'
        url = item.get('url', '#')
        
        # 从 URL 提取来源
        source = extract_source(url)
        
        # 判断标签
        title_lower = title.lower()
        if any(kw in title_lower for kw in ['attack', 'strike', 'missile', 'war', 'kill']):
            tags = ['military']
            urgent = True
        elif any(kw in title_lower for kw in ['oil', 'price', 'market', 'stock']):
            tags = ['economy']
            urgent = False
        else:
            tags = ['diplomacy']
            urgent = False
        
        news_items.append({
            "id": i,
            "time": datetime.now().strftime("%Y-%m-%d %H:%M"),
            "title": title,
            "content": content,
            "source": source,
            "sourceUrl": url,
            "tags": tags,
            "urgent": urgent
        })
    
    # 读取并更新 HTML
    with open(html_file, 'r', encoding='utf-8') as f:
        html = f.read()
    
    # 替换新闻数据
    news_json = json.dumps(news_items, indent=4, ensure_ascii=False)
    html = re.sub(r'const newsData = \[.*?\];', f'const newsData = {news_json};', html, flags=re.DOTALL)
    
    # 更新时间
    time_str = datetime.now().strftime("%Y-%m-%d %H:%M")
    html = re.sub(r'(id="last-update">)[^<]+', f'\\1{time_str} (GMT+8)', html)
    
    with open(html_file, 'w', encoding='utf-8') as f:
        f.write(html)
    
    print(f"Updated {len(news_items)} news items")
    
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYSCRIPT

rm -f "$RESPONSE_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新完成" >> "$LOG_FILE"

# Git 提交
cd "$PROJECT_DIR"
git add index.html
git diff --quiet && git diff --staged --quiet || {
    git commit -m "Auto-update: $(date '+%Y-%m-%d %H:%M')" > /dev/null 2>&1
    git push origin main 2>/dev/null || echo "Push skipped"
}