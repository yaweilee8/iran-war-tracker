#!/bin/bash
# Iran War Tracker - 自动新闻+视频更新脚本
set -e

PROJECT_DIR="/Users/yawei/.openclaw/workspace/iran-war-tracker"
LOG_FILE="$PROJECT_DIR/logs/update.log"
HTML_FILE="$PROJECT_DIR/index.html"
TAVILY_API_KEY="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"

mkdir -p "$PROJECT_DIR/logs"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始更新新闻和视频..." >> "$LOG_FILE"

# 抓取文字新闻
NEWS_RESPONSE=$(curl -s -X POST "https://api.tavily.com/search" \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API_KEY\",
        \"query\": \"Iran Israel war conflict latest news\",
        \"topic\": \"news\",
        \"days\": 1,
        \"max_results\": 8,
        \"search_depth\": \"basic\"
    }")

# 抓取 YouTube 视频
VIDEO_RESPONSE=$(curl -s -X POST "https://api.tavily.com/search" \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API_KEY\",
        \"query\": \"Iran Israel war YouTube video news\",
        \"include_domains\": [\"youtube.com\", \"youtu.be\"],
        \"days\": 1,
        \"max_results\": 5,
        \"search_depth\": \"basic\"
    }")

# 保存响应到临时文件
NEWS_FILE=$(mktemp)
VIDEO_FILE=$(mktemp)
echo "$NEWS_RESPONSE" > "$NEWS_FILE"
echo "$VIDEO_RESPONSE" > "$VIDEO_FILE"

# 使用 Python 更新 HTML
python3 - "$NEWS_FILE" "$VIDEO_FILE" "$HTML_FILE" << 'PYSCRIPT'
import json
import re
import sys
from datetime import datetime
from urllib.parse import urlparse

def extract_source(url):
    """从 URL 提取域名作为来源"""
    try:
        domain = urlparse(url).netloc
        if domain.startswith('www.'):
            domain = domain[4:]
        if 'youtube.com' in domain or 'youtu.be' in domain:
            return 'YouTube'
        parts = domain.split('.')
        if len(parts) >= 2:
            return parts[0].capitalize()
        return domain.capitalize()
    except:
        return 'Unknown'

def extract_youtube_id(url):
    """从 YouTube URL 提取视频 ID"""
    import re
    patterns = [
        r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([^&\s?]+)',
        r'youtube\.com/shorts/([^&\s?]+)'
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None

news_file = sys.argv[1]
video_file = sys.argv[2]
html_file = sys.argv[3]

try:
    # 读取新闻数据
    with open(news_file, 'r') as f:
        news_data = json.load(f)
    
    # 读取视频数据
    with open(video_file, 'r') as f:
        video_data = json.load(f)
    
    # 处理新闻
    news_items = []
    for i, item in enumerate(news_data.get('results', [])[:8], 1):
        title = item.get('title', 'No title')
        content = item.get('content', '')[:180] + '...' if item.get('content') else 'No content'
        url = item.get('url', '#')
        source = extract_source(url)
        
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
            "urgent": urgent,
            "type": "news"
        })
    
    # 处理视频
    video_items = []
    for i, item in enumerate(video_data.get('results', [])[:5], 1):
        title = item.get('title', 'No title')
        url = item.get('url', '#')
        video_id = extract_youtube_id(url)
        
        if video_id:
            video_items.append({
                "id": f"v{i}",
                "time": datetime.now().strftime("%Y-%m-%d %H:%M"),
                "title": title,
                "source": "YouTube",
                "sourceUrl": url,
                "videoId": video_id,
                "thumbnail": f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg",
                "type": "video"
            })
    
    # 合并并按时间排序（这里简化处理，视频放前面）
    all_items = video_items + news_items
    
    # 读取并更新 HTML
    with open(html_file, 'r', encoding='utf-8') as f:
        html = f.read()
    
    # 替换新闻数据
    news_json = json.dumps(all_items, indent=4, ensure_ascii=False)
    html = re.sub(r'const newsData = \[.*?\];', f'const newsData = {news_json};', html, flags=re.DOTALL)
    
    # 更新时间
    time_str = datetime.now().strftime("%Y-%m-%d %H:%M")
    html = re.sub(r'(id="last-update">)[^<]+', f'\\1{time_str} (GMT+8)', html)
    
    with open(html_file, 'w', encoding='utf-8') as f:
        f.write(html)
    
    print(f"Updated {len(news_items)} news + {len(video_items)} videos")
    
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYSCRIPT

rm -f "$NEWS_FILE" "$VIDEO_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新完成" >> "$LOG_FILE"

# Git 提交
cd "$PROJECT_DIR"
git add index.html
git diff --quiet && git diff --staged --quiet || {
    git commit -m "Auto-update: $(date '+%Y-%m-%d %H:%M')" > /dev/null 2>&1
    git push origin main 2>/dev/null || echo "Push skipped"
}