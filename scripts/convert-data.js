// 转换 Tavily 数据格式到网站格式
const fs = require('fs');

// 读取原始数据
const rawData = JSON.parse(fs.readFileSync('data/news-data.json', 'utf8'));

// 转换函数
function convertNewsData(raw) {
    const newsItems = [];
    
    if (raw.results && Array.isArray(raw.results)) {
        raw.results.forEach((item, index) => {
            // 提取时间
            let time = '2026-03-17';
            if (item.published_date) {
                try {
                    const date = new Date(item.published_date);
                    time = date.toLocaleString('zh-CN', {
                        year: 'numeric',
                        month: '2-digit',
                        day: '2-digit',
                        hour: '2-digit',
                        minute: '2-digit'
                    });
                } catch(e) {
                    time = '2026-03-17 08:00';
                }
            }
            
            // 确定标签
            const tags = [];
            const content = (item.content || item.title || '').toLowerCase();
            if (content.includes('military') || content.includes('strike') || content.includes('attack') || content.includes('missile') || content.includes('force')) {
                tags.push('military');
            }
            if (content.includes('diplomacy') || content.includes('talk') || content.includes('negotiation') || content.includes('peace') || content.includes('deal')) {
                tags.push('diplomacy');
            }
            if (content.includes('economy') || content.includes('oil') || content.includes('price') || content.includes('market') || content.includes('trade')) {
                tags.push('economy');
            }
            if (tags.length === 0) {
                tags.push('military'); // 默认标签
            }
            
            // 判断是否紧急
            const urgent = content.includes('killed') || content.includes('death') || content.includes('urgent') || content.includes('breaking');
            
            // 截取内容（限制长度）
            let contentText = item.content || '';
            if (contentText.length > 300) {
                contentText = contentText.substring(0, 300) + '...';
            }
            
            newsItems.push({
                time: time,
                title: item.title || 'Untitled',
                content: contentText,
                source: item.siteName || extractSource(item.url) || 'News Source',
                sourceUrl: item.url || '#',
                tags: tags,
                urgent: urgent,
                type: 'news'
            });
        });
    }
    
    return newsItems;
}

function extractSource(url) {
    if (!url) return 'Unknown';
    try {
        const hostname = new URL(url).hostname;
        return hostname.replace('www.', '').split('.')[0];
    } catch(e) {
        return 'News Source';
    }
}

// 转换数据
const converted = convertNewsData(rawData);

// 保存为 JavaScript 文件
const jsContent = `// 自动生成的伊朗战争新闻数据
// 更新时间: ${new Date().toISOString()}
const newsData = ${JSON.stringify(converted, null, 2)};`;

fs.writeFileSync('data/news.js', jsContent);
console.log(`✅ 已转换 ${converted.length} 条新闻`);
console.log('📁 文件保存至: data/news.js');
