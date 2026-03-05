const fs = require('fs');
const path = require('path');

// 使用 Tavily API 获取新闻
async function fetchNews() {
    const apiKey = process.env.TAVILY_API_KEY;
    
    if (!apiKey) {
        console.log('No API key, using mock data');
        return;
    }
    
    try {
        const response = await fetch('https://api.tavily.com/search', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                api_key: apiKey,
                query: 'Iran Israel war latest news today',
                topic: 'news',
                days: 1,
                max_results: 10,
                include_answer: true
            })
        });
        
        const data = await response.json();
        
        // 转换为网站格式
        const newsItems = data.results.map((item, index) => ({
            id: index + 1,
            time: new Date().toISOString(),
            title: item.title,
            content: item.content?.substring(0, 200) + '...' || 'No content',
            source: item.source || 'Unknown',
            sourceUrl: item.url,
            tags: ['military'],
            urgent: item.title?.includes('attack') || item.title?.includes('strike')
        }));
        
        // 读取现有 HTML
        const htmlPath = path.join(__dirname, '..', 'index.html');
        let html = fs.readFileSync(htmlPath, 'utf8');
        
        // 替换新闻数据
        const newsDataScript = `const newsData = ${JSON.stringify(newsItems, null, 4)};`;
        html = html.replace(/const newsData = \[\s*\]/, newsDataScript);
        
        // 写回文件
        fs.writeFileSync(htmlPath, html);
        
        console.log(`Updated ${newsItems.length} news items`);
        
    } catch (error) {
        console.error('Error fetching news:', error);
    }
}

fetchNews();