# Iran War Tracker - 伊朗战争实时追踪网站

## 功能特点

- 🔴 实时战争时间线
- 📰 多源新闻聚合（BBC, Reuters, Al Jazeera）
- 🏷️ 自动分类（军事/外交/经济）
- 📱 响应式设计，支持移动端
- ⚡ 自动刷新数据

## 本地预览

```bash
cd ~/.openclaw/workspace/iran-war-tracker
python3 -m http.server 8080
# 打开 http://localhost:8080
```

## 部署方案

### 方案 1：GitHub Pages（免费）
1. 创建 GitHub 仓库
2. 上传 index.html
3. 开启 GitHub Pages
4. 访问 https://你的用户名.github.io/iran-war-tracker

### 方案 2：Cloudflare Pages（免费+自动刷新）
1. 注册 Cloudflare
2. 连接 GitHub 仓库
3. 自动部署

### 方案 3：Netlify（免费）
1. 拖拽文件夹到 Netlify
2. 获得免费域名

## 数据更新

当前使用静态数据，如需自动更新：

### 选项 A：手动更新
编辑 `index.html` 中的 `newsData` 数组

### 选项 B：API 自动获取（推荐）
创建后端服务定期抓取新闻：
```javascript
// 使用 Tavily API 获取最新新闻
fetch('https://api.tavily.com/search', {
  method: 'POST',
  body: JSON.stringify({
    query: 'Iran Israel war latest news',
    topic: 'news',
    days: 1
  })
})
```

## 数据来源

- BBC News
- Reuters  
- Al Jazeera
- NYT

## 免责声明

本网站仅聚合公开新闻来源，不构成军事或投资建议。

## 技术栈

- HTML5
- CSS3 (响应式设计)
- Vanilla JavaScript
- 无后端依赖（静态网站）