'use strict';

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
const escapeText = value => String(value).replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
const icon = name => `<svg class="icon" aria-hidden="true"><use href="#i-${name}"/></svg>`;
const action = (name, value = '') => `data-action="${name}" data-value="${escapeText(value)}"`;
const go = page => action('go', page);
const initialItems = [
  { id:'reply', type:'text', title:'常用回复', text:'你好，资料已收到，我稍后回复你。', pinned:true, meta:'文字' },
  { id:'clipcv', type:'link', title:'ClipCV', text:'https://github.com/wangsendi/ClipCV', pinned:true, meta:'来自 Mac' },
  { id:'photo', type:'image', title:'周末的海边', text:'图片 · 1.8 MB', pinned:false, meta:'2 分钟前' },
  { id:'plan', type:'text', title:'下一版要做的事', text:'先做好自动记录，再把常用的句子钉起来。', pinned:false, meta:'5 分钟前' },
  { id:'docs', type:'link', title:'SwiftUI Documentation', text:'https://developer.apple.com/documentation/swiftui', pinned:false, meta:'12 分钟前' },
  { id:'address', type:'text', title:'周末见面', text:'周六下午两点，我们在图书馆门口见。', pinned:false, meta:'18 分钟前' }
];
const state = {
  group:'history', mode:'gallery', page:'home', items:structuredClone(initialItems),
  filter:'all', query:'周末', homeQuery:'', paused:false, autoRecord:true,
  types:{text:true, link:true, rich:true, image:true}, syncSetting:true, syncActual:true, syncStatus:'enabled',
  countLimit:'200', sizeLimit:'300', appearance:'system', language:'system',
  selected:'reply', keyboardTab:'recent', draft:'好的，', messages:[],
  markdownMode:'rendered', jsonMode:'formatted', zoom:1, color:'#A8E66C', shareSaved:false, fileAvailable:true
};

function circle(name, attributes, label, small = false) {
  return `<button class="circle-button${small ? ' small' : ''}" ${attributes} aria-label="${escapeText(label)}">${icon(name)}</button>`;
}
function nav(title, back = 'home', right = '') {
  return `<nav class="nav">${circle('back',go(back),'返回')}<span>${title}</span>${right || '<span class="nav-space"></span>'}</nav>`;
}
function footer(label, attributes, name = 'copy', secondary = '') {
  return `<footer class="footer-actions"><button class="primary" ${attributes}>${icon(name)}<span>${label}</span></button>${secondary}</footer>`;
}
function settingIcon(name, green = false) {
  return `<span class="setting-icon${green ? ' green' : ''}">${icon(name)}</span>`;
}
function row(name, label, value = '', target = '', green = false) {
  const content = `${settingIcon(name,green)}<span class="row-label">${label}</span><span class="value">${value}</span>${target ? icon('chevron').replace('class="icon"','class="icon chevron"') : ''}`;
  return target ? `<button class="setting-row" ${go(target)}>${content}</button>` : `<div class="setting-row">${content}</div>`;
}
function toggle(name, label, checked) {
  return `<button class="switch${checked ? ' on' : ''}" role="switch" aria-checked="${checked}" aria-label="${label}" ${action('toggle',name)}></button>`;
}
function toggleRow(name, label, checked, symbol, green = false) {
  return `<div class="setting-row">${settingIcon(symbol,green)}<span class="row-label">${label}</span>${toggle(name,label,checked)}</div>`;
}
function group(label, content, note = '') {
  return `<p class="group-title">${label}</p><div class="settings-card">${content}</div>${note ? `<p class="note">${note}</p>` : ''}`;
}
function info(rows) {
  return `<div class="info-card">${rows.map(([label,value]) => `<div class="info-row"><span>${label}</span><strong>${value}</strong></div>`).join('')}</div>`;
}
function art(className = '', slice = false) {
  return `<svg class="${className}" viewBox="0 0 300 350"${slice ? ' preserveAspectRatio="xMidYMid slice"' : ''} role="img" aria-label="海边插画示例"><use href="#i-sea"/></svg>`;
}
function brand() { return '<span class="brand-mark">CV</span>'; }
function copyButton(id) { return circle('copy',action('copy',id),'复制',true); }
function card(item, context = '') {
  const attrs = context === 'decorative' ? '' : go(item.type === 'image' ? 'image-detail' : item.type === 'link' ? 'link-detail' : 'text-detail');
  const copy = context === 'decorative' ? '' : copyButton(item.id);
  if (item.type === 'image') {
    return `<article class="history-card" data-id="${item.id}" data-type="image" ${attrs} tabindex="0" role="button" aria-label="查看${escapeText(item.title)}"><div class="image-row"><div class="thumb">${art('',true)}</div><div class="image-info"><div class="card-title">${escapeText(item.title)}</div><p class="card-text">${escapeText(item.text)}</p><span class="card-meta">${item.meta}</span></div>${copy}</div></article>`;
  }
  return `<article class="history-card${item.pinned ? ' pinned' : ''}" data-id="${item.id}" data-type="${item.type}" ${attrs} tabindex="0" role="button" aria-label="查看${escapeText(item.title)}"><div class="card-top"><span class="kind-icon${item.pinned ? ' green' : ''}">${icon(item.type === 'link' ? 'link' : 'text')}</span><span class="card-title">${escapeText(item.title)}</span><div class="card-actions">${item.pinned && context !== 'decorative' ? `<button class="pin-toggle" ${action('pin',item.id)} aria-label="取消钉选">${icon('pin')}</button>` : ''}${copy}</div></div><p class="card-text">${escapeText(item.text.replace(/^https:\/\//,''))}</p><div class="card-meta">${item.pinned ? `<span class="pin-tag">${icon('pin')}钉选</span>` : `<span>${item.meta}</span>`}<span>${item.pinned ? item.meta : '来自 iPhone'}</span></div></article>`;
}
function appHeader(title = 'ClipCV') {
  return `<header class="app-header"><div><h2>${title}</h2><div class="record-status"><i class="dot${state.paused ? ' gray' : ''}"></i><span>${state.paused ? '已暂停' : '前台记录中'}</span></div></div>${circle('settings',go('settings'),'设置')}</header>`;
}
function searchField(value = '', key = 'home-query') {
  return `<label class="search">${icon('search')}<input type="search" data-input="${key}" value="${escapeText(value)}" placeholder="搜索历史记录" aria-label="搜索历史记录"><span class="search-count" data-result-count></span></label>`;
}
function chips(selected = 'all') {
  return `<div class="chips">${[['all','全部'],['pinned','钉选'],['text','文字'],['link','链接'],['image','图片']].map(([value,label]) => `<button class="chip${selected === value ? ' active' : ''}" ${action('filter',value)}>${label}</button>`).join('')}</div>`;
}
function historyResults(kind) {
  const query = kind === 'search' ? state.query : state.homeQuery;
  const filter = kind === 'pinned' ? 'pinned' : kind === 'search' ? 'all' : state.filter;
  const available = state.items.filter(item => (filter === 'all' || (filter === 'pinned' ? item.pinned : item.type === filter)) && (!query || `${item.title} ${item.text}`.toLowerCase().includes(query.toLowerCase())));
  const pinned = available.filter(item => item.pinned), recent = available.filter(item => !item.pinned);
  if (!available.length) return `<div class="empty-state"><div class="empty-orbit">${circle('search',action('clear-search'),'清除搜索')}</div><h3>无匹配记录</h3></div>`;
  return `${pinned.length ? `<div class="section-label"><span>钉选</span><small>${pinned.length} 项</small></div>${pinned.map(i => card(i)).join('')}` : ''}${recent.length ? `<div class="section-label"><span>${kind === 'search' ? '搜索结果' : '最近'}</span><small>${kind === 'search' ? `${available.length} 项` : '今天'}</small></div>${recent.map(i => card(i)).join('')}` : ''}`;
}
function home(kind = 'home') {
  const pinned = kind === 'pinned', search = kind === 'search';
  return `${appHeader(pinned ? '钉选' : 'ClipCV')}${searchField(search ? state.query : state.homeQuery,search ? 'query' : 'home-query')}${chips(pinned ? 'pinned' : search ? 'all' : state.filter)}<div class="scroll" data-results="${kind}">${historyResults(kind)}</div>${footer('记录设置',go('recording'),'clock',circle(state.paused ? 'play' : 'pause',action('pause'),state.paused ? '恢复记录' : '暂停记录'))}`;
}
function welcome() {
  return `<div class="welcome">${brand()}<h2>ClipCV</h2><p>剪贴板历史</p><div class="welcome-stack">${card(initialItems[0],'decorative')}${card(initialItems[2],'decorative')}</div><p class="note">打开应用时自动记录。</p></div>${footer('开始记录',action('start'),'play')}`;
}
function empty(noResults = false) {
  return `${appHeader()}${searchField(noResults ? '火星旅行' : '', 'empty-query')}${chips()}<div class="empty-state"><div class="empty-orbit">${circle(noResults ? 'search' : 'copy',action('noop'),noResults ? '搜索' : '剪贴板')}</div><h3>${noResults ? '无匹配记录' : '暂无记录'}</h3>${noResults ? `<button class="chip" ${go('search')}>重新搜索</button>` : ''}</div>${footer('记录设置',go('recording'),'clock',circle('pause',action('pause'),'暂停记录'))}`;
}
function textDetail() {
  const item = state.items.find(i => i.id === state.selected && i.type === 'text') || state.items.find(i => i.id === 'reply') || initialItems[0];
  return `${nav('文字','home',circle('more',action('menu',item.id),'更多操作'))}<div class="scroll"><p class="detail-date">今天 09:36</p><div class="text-paper"><p>${escapeText(item.text)}</p></div><h3 class="detail-title">${escapeText(item.title)}</h3><div class="detail-meta"><span class="tag">文字</span><span>${item.text.length} 字符</span><span>·</span><span>来自 iPhone</span></div><div class="secondary-actions"><button ${action('edit-item',item.id)}>${icon('edit')}编辑</button><button ${action('pin',item.id)}>${icon('pin')}${item.pinned ? '取消钉选' : '钉选'}</button></div>${info([['首次复制','今天 09:36'],['使用次数','3 次']])}</div>${footer('复制',action('copy',item.id),'copy',circle('share',action('share-text'),'分享'))}`;
}
function linkDetail() {
  const item = state.items.find(i => i.id === state.selected && i.type === 'link') || state.items.find(i => i.id === 'clipcv') || initialItems[1];
  return `${nav('链接','home',circle('more',action('menu',item.id),'更多操作'))}<div class="scroll"><p class="detail-date">今天 09:32 · 来自 Mac</p><div class="link-art">${item.id === 'clipcv' ? brand() : icon('link')}</div><h3 class="detail-title">${escapeText(item.title)}</h3><div class="link-url">${escapeText(item.text)}</div><div class="secondary-actions"><button ${action('open-link',item.text)}>${icon('globe')}打开链接</button><button ${action('pin',item.id)}>${icon('pin')}${item.pinned ? '取消钉选' : '钉选'}</button></div>${info([['格式','URL'],['来源','Mac']])}</div>${footer('复制链接',action('copy',item.id),'copy',circle('share',action('share-text'),'分享'))}`;
}
function imageDetail() {
  return `${nav('图片','home',circle('more',action('menu','photo'),'更多操作'))}<div class="scroll"><p class="detail-date">今天 09:38</p><div class="photo-wrap">${art()}<button class="photo-expand" ${go('image-viewer')} aria-label="全屏预览">${icon('expand')}</button></div><h3 class="detail-title">${escapeText(state.items.find(i => i.id === 'photo')?.title || initialItems[2].title)}</h3><div class="detail-meta"><span class="tag">PNG</span><span>1600 × 1200</span><span>·</span><span>1.8 MB</span></div>${info([['来源','Mac']])}<div class="secondary-actions"><button ${action('pin','photo')}>${icon('pin')}${state.items.find(i => i.id === 'photo')?.pinned ? '取消钉选' : '钉选'}</button></div></div>${footer('复制图片',action('copy','photo'),'copy',circle('share',action('share-text'),'分享图片'))}`;
}
function edit() {
  const item = state.items.find(i => i.id === state.selected) || state.items.find(i => i.id === 'reply') || initialItems[0];
  const detail = item.type === 'image' ? 'image-detail' : item.type === 'link' ? 'link-detail' : 'text-detail';
  return `${nav('编辑',detail,`<button class="text-button" ${action('save-edit',item.id)} style="color:#7ca34e;font-size:12px">完成</button>`)}<div class="scroll"><div class="edit-fields"><div class="input-card"><label for="edit-title">标题</label><input id="edit-title" value="${escapeText(item.title)}" maxlength="80"></div>${item.type !== 'image' ? `<div class="input-card"><label for="edit-text">内容</label><textarea id="edit-text">${escapeText(item.text)}</textarea></div>` : ''}</div></div>${systemKeys()}`;
}
function viewer() {
  return `${nav('1 / 1','image-detail',circle('share',action('share-text'),'分享图片'))}<div style="flex:1;overflow:hidden;display:flex;align-items:center">${art('viewer-art').replace('class="viewer-art"',`class="viewer-art" style="transform:scale(${state.zoom})"`)}</div><p class="viewer-note">1600 × 1200</p><div class="zoom-controls">${[1,1.5,2].map(n => `<button class="${state.zoom === n ? 'active' : ''}" ${action('zoom',n)}>${n}×</button>`).join('')}</div>${footer('复制图片',action('copy','photo'))}`;
}
function menu() {
  const item = state.items.find(i => i.id === state.selected) || state.items[0] || initialItems[0];
  return `${nav('历史','home')}<div class="menu-stage"><div class="menu-selected">${card(item,'decorative')}</div><div class="context-menu"><button ${action('copy',item.id)}>${icon('copy')}复制</button>${item.type !== 'image' ? `<button ${action('copy-plain',item.id)}>${icon('text')}复制纯文本</button>` : ''}<button ${action('pin',item.id)}>${icon('pin')}${item.pinned ? '取消钉选' : '钉选'}</button><button ${action('edit-item',item.id)}>${icon('edit')}${item.type === 'image' ? '编辑标题' : '编辑'}</button><button ${action('share-text')}>${icon('share')}分享</button><button class="danger" ${action('delete',item.id)}>${icon('trash')}删除</button></div></div>`;
}
function syncPending() { return state.syncSetting !== state.syncActual; }
function syncLabel() {
  if (state.syncStatus === 'unavailable') return 'iCloud 不可用';
  if (!state.syncActual) return '已关闭';
  return state.syncStatus === 'transferring' ? '正在传输' : '已启用';
}
function pendingNote() {
  return syncPending() ? `<p class="note strong" data-sync-pending>重开后${state.syncSetting ? '开启' : '关闭'}，当前${state.syncActual ? '已启用' : '已关闭'}。</p>` : '';
}
function settings() {
  return `${nav('设置') }<div class="scroll">${group('记录',toggleRow('auto','前台自动记录',state.autoRecord,'clock',true)+row('photo','记录类型',Object.values(state.types).every(Boolean) ? '全部' : '自定义','types')+row('keyboard','剪贴板键盘','待启用','keyboard-setup'))}${group('同步',toggleRow('sync','iCloud 同步',state.syncSetting,'cloud',true)+row('check','当前状态',syncLabel(),'sync'))}${pendingNote()}${group('存储',row('storage','历史与空间',`${state.countLimit} 条 / ${state.sizeLimit === '1024' ? '1 GB' : state.sizeLimit + ' MB'}`,'storage'))}${group('通用',row('globe','语言与外观','跟随系统','appearance'))}<div class="hero-state" style="padding:30px 0 8px"><span class="brand-mark" style="width:35px;height:35px;font-size:16px;border-radius:12px;letter-spacing:-2px">CV</span><p style="margin-top:10px">ClipCV · iOS</p></div></div>`;
}
function types() {
  return `${nav('记录类型','settings')}<div class="scroll">${group('收录',toggleRow('type-text','文字',state.types.text,'text')+toggleRow('type-link','链接',state.types.link,'link')+toggleRow('type-rich','富文本',state.types.rich,'edit')+toggleRow('type-image','图片',state.types.image,'photo'))}</div>`;
}
function recording() {
  return `${nav('记录','home')}<div class="scroll"><div class="hero-state"><div class="hero-icon">${icon(state.paused ? 'pause' : 'clock')}</div><h3>${state.paused ? '已暂停' : '前台记录中'}</h3></div>${group('记录',toggleRow('auto','前台自动记录',state.autoRecord,'clock',true)+row('photo','记录类型','','types'))}${group('同步',row('cloud','iCloud',syncLabel(),'sync'))}</div>${footer(state.paused ? '继续记录' : '暂停记录',action('pause'),state.paused ? 'play' : 'pause')}`;
}
function sync() {
  return `${nav('iCloud 同步','settings')}<div class="scroll">${group('同步',toggleRow('sync','iCloud 同步',state.syncSetting,'cloud',true))}${pendingNote()}${!syncPending() ? '<p class="note">更改后需重开应用。</p>' : ''}${group('状态',row('check','当前状态',syncLabel())+row('storage','本机历史',`${state.items.length} 条`),state.syncStatus === 'unavailable' ? '检查 iCloud 账户或网络。' : '')}</div>`;
}
function storage() {
  const used = state.items.length ? '34.8' : '0';
  return `${nav('历史与空间','settings')}<div class="scroll"><div class="storage-chart"><div><strong>${used}<span style="font-size:11px;letter-spacing:0"> MB</span></strong><small>本机历史占用</small></div></div>${group('历史上限',`<div class="setting-row">${settingIcon('storage')}<span>最多保留</span><select class="value" data-select="countLimit" aria-label="历史条数上限" style="border:0;background:none">${['200','500','999'].map(v => `<option value="${v}"${state.countLimit === v ? ' selected' : ''}>${v} 条</option>`).join('')}</select></div><div class="setting-row">${settingIcon('photo')}<span>存储上限</span><select class="value" data-select="sizeLimit" aria-label="存储空间上限" style="border:0;background:none">${[['300','300 MB'],['1024','1 GB']].map(([v,l]) => `<option value="${v}"${state.sizeLimit === v ? ' selected' : ''}>${l}</option>`).join('')}</select></div>`,'自动清理保留钉选。')}${group('内容',row('pin','钉选',`${state.items.filter(i => i.pinned).length} 条`)+row('clock','全部历史',`${state.items.length} 条`))}${group('清理',`<button class="clear-button" ${action('clear-unpinned')}>${icon('trash')}清空未钉选</button><button class="clear-button danger" ${action('clear-all')}>${icon('trash')}清空全部历史</button>`,state.syncActual ? '删除会同步到其他设备。' : '')}</div>`;
}
function appearance() {
  return `${nav('语言与外观','settings')}<div class="scroll">${group('外观',`<div class="appearance-options">${[['light','浅色',''],['dark','深色','dark'],['system','跟随系统','auto']].map(([v,l,c]) => `<button class="appearance-choice${state.appearance === v ? ' active' : ''}" ${action('appearance',v)}><div class="mini-phone ${c}"><i></i><i></i><i></i></div>${l}</button>`).join('')}</div>`)}${group('语言',`<div class="setting-row">${settingIcon('globe')}<span>显示语言</span><select class="value" data-select="language" aria-label="显示语言" style="border:0;background:none">${[['system','跟随系统'],['zh','简体中文'],['en','English']].map(([v,l]) => `<option value="${v}"${state.language === v ? ' selected' : ''}>${l}</option>`).join('')}</select></div>`)}<div class="hero-state" style="padding-top:43px">${brand()}<h3 style="font-size:19px;margin-top:16px">ClipCV</h3></div><div class="secondary-actions" style="justify-content:center"><button ${action('repository')}>${icon('code')}GitHub</button></div></div>`;
}
function keyboardSetup() {
  return `${nav('剪贴板键盘','settings')}<div class="scroll">${group('启用',`<div class="step"><span class="step-index">1</span><div><strong>添加 ClipCV 键盘</strong><p>设置 → 通用 → 键盘 → 键盘<br>添加新键盘 → ClipCV</p></div></div><div class="step"><span class="step-index">2</span><div><strong>切换键盘</strong><p>长按地球键，选择 ClipCV。</p></div></div>`)}</div>${footer('试用键盘',go('keyboard'),'keyboard')}`;
}
function systemKeys() {
  return `<section class="simple-keys"><div class="candidates"><span>周末</span><span>周末去</span><span>周末计划</span></div>${['qwertyuiop','asdfghjkl','zxcvbnm'].map((row,index) => `<div class="keyrow">${index === 2 ? '<span class="key wide">⇧</span>' : ''}${row.split('').map(k => `<span class="key">${k}</span>`).join('')}${index === 2 ? '<span class="key wide">⌫</span>' : ''}</div>`).join('')}<div class="keyrow last"><span class="key wide" style="font-size:10px">123</span><span class="key space">空格</span><span class="key return">换行</span></div><div class="key-footer"><button ${go('keyboard')} aria-label="切换到 ClipCV 键盘">${icon('globe')}</button>${icon('keyboard')}</div></section>`;
}
function snippets() {
  const available = state.items.filter(i => i.type !== 'image' && (state.keyboardTab !== 'pinned' || i.pinned));
  return available.length ? available.map(item => `<button class="snippet" ${action('insert',item.id)}><span class="snippet-text"><span class="snippet-title">${escapeText(item.text)}</span><span class="snippet-sub">${escapeText(item.title)}${item.pinned ? ' · 钉选' : ''}</span></span><span class="insert-button">${icon('insert')}</span></button>`).join('') : '<p class="note center" style="padding-top:30px">暂无文字记录</p>';
}
function keyboard(isSystem = false) {
  return `<div class="chat-nav">${icon('back')}<span>阿林</span>${icon('more')}</div><div class="chat-body"><p class="chat-time">09:41</p><div class="message-line"><span class="avatar">L</span><div class="bubble">周末的安排确定了吗？</div></div><div class="message-line sent"><div class="bubble">好呀，稍等我发你。</div></div>${state.messages.map(message => `<div class="message-line sent"><div class="bubble">${escapeText(message)}</div></div>`).join('')}</div><div class="composer"><textarea data-input="draft" aria-label="聊天输入框" rows="1">${escapeText(state.draft)}</textarea><button class="send-button" ${action('send')} aria-label="发送示例消息">${icon('up')}</button></div>${isSystem ? systemKeys() : `<section class="clip-keyboard"><div class="keyboard-top"><div class="keyboard-brand">${brand()}ClipCV</div><div class="keyboard-tabs">${[['recent','最近'],['pinned','钉选']].map(([v,l]) => `<button class="${state.keyboardTab === v ? 'active' : ''}" ${action('keyboard-tab',v)}>${l}</button>`).join('')}</div></div><div class="snippet-list">${snippets()}</div><div class="keyboard-footer"><button class="keyboard-switch" ${go('keyboard-system')}>${icon('globe')}切回输入法</button>${icon('keyboard')}</div></section>`}`;
}
function ocr() {
  return `${nav('识别文字','image-detail')}<div class="scroll"><div class="ocr-photo"><div class="document"><strong>周末的小计划</strong><p>收拾书桌，去海边走走。<br>把时间留给喜欢的事情。</p></div><div class="ocr-box"></div></div><div class="section-label" style="margin-top:12px"><span>识别结果</span><small>36 字符</small></div><div class="text-paper" style="min-height:190px;padding:10px 16px"><div class="ocr-result" contenteditable="true" role="textbox" aria-label="识别结果">周末的小计划\n收拾书桌，去海边走走。\n把时间留给喜欢的事情。</div></div></div>${footer('复制文字',action('copy-ocr'),'copy')}`;
}
const markdownText = '# 周末的小计划\n\n把时间留给喜欢的事情。\n\n## 准备清单\n- 收拾一下书桌\n- 去海边走走\n- 给自己买一束花\n\n> 慢一点，也很好。';
function markdown() {
  return `${nav('Markdown','home',circle('more',go('record-menu'),'更多操作'))}<div class="scroll"><div class="segmented">${[['rendered','预览'],['source','原文']].map(([v,l]) => `<button class="${state.markdownMode === v ? 'active' : ''}" ${action('markdown-mode',v)}>${l}</button>`).join('')}</div>${state.markdownMode === 'source' ? `<pre class="code-paper">${escapeText(markdownText)}</pre>` : '<div class="text-paper markdown"><h3>周末的小计划</h3><p>把时间留给喜欢的事情。</p><h4>准备清单</h4><ul><li>收拾一下书桌</li><li>去海边走走</li><li>给自己买一束花</li></ul><blockquote>慢一点，也很好。</blockquote></div>'}</div>${footer('复制原文',action('copy-markdown'),'copy')}`;
}
function json() {
  const content = state.jsonMode === 'source' ? '{"name":"ClipCV","platforms":["macOS","iOS"],"sync":true,"history":{"limit":200,"keepPinned":true}}' : '{\n  <span class="key-name">"name"</span>: <span class="string">"ClipCV"</span>,\n  <span class="key-name">"platforms"</span>: [\n    <span class="string">"macOS"</span>,\n    <span class="string">"iOS"</span>\n  ],\n  <span class="key-name">"sync"</span>: true,\n  <span class="key-name">"history"</span>: {\n    <span class="key-name">"limit"</span>: 200,\n    <span class="key-name">"keepPinned"</span>: true\n  }\n}';
  return `${nav('JSON','home',circle('more',go('record-menu'),'更多操作'))}<div class="scroll"><div class="segmented">${[['formatted','格式化'],['source','原文']].map(([v,l]) => `<button class="${state.jsonMode === v ? 'active' : ''}" ${action('json-mode',v)}>${l}</button>`).join('')}</div><pre class="code-paper">${content}</pre><div class="detail-meta" style="margin-top:16px"><span class="tag">JSON</span><span>UTF-8</span></div></div>${footer(state.jsonMode === 'source' ? '复制原文' : '复制格式化结果',action('copy-json'),'copy')}`;
}
function color() {
  const hex = state.color.slice(1), values = [0,2,4].map(offset => parseInt(hex.slice(offset,offset + 2),16));
  return `${nav('颜色','home',circle('more',go('record-menu'),'更多操作'))}<div class="scroll"><div class="color-swatch" style="background:${state.color}"><strong>${state.color}</strong></div><div class="colors-row">${['#A8E66C','#DCEACB','#B4CCC4','#F5DDD1','#D9DAAF'].map(c => `<button class="${state.color === c ? 'active' : ''}" style="background:${c}" ${action('color',c)} aria-label="颜色 ${c}"></button>`).join('')}</div>${info([['HEX',state.color],['RGB',values.join(', ')]])}</div>${footer('复制色值',action('copy-color'),'copy')}`;
}
function share() {
  return `<div class="share-host"><p style="font-size:10px;margin:14px 0 0">Safari · github.com</p><h3>ClipCV</h3></div><div class="share-sheet"><div class="sheet-handle"></div><div class="sheet-title"><span class="keyboard-brand">${brand()}ClipCV</span>${circle('x',go('home'),'关闭')}</div>${state.shareSaved ? `<div class="hero-state" style="padding-top:45px"><div class="hero-icon">${icon('check')}</div><h3>已接收</h3><p>打开 ClipCV 后加入历史。</p></div>` : '<div class="share-preview"><div class="link-art">'+brand()+'</div><h3>ClipCV</h3><p>github.com/wangsendi/ClipCV</p></div><p class="note">链接 · 1 项</p>'}</div>${footer(state.shareSaved ? '完成' : '保存到 ClipCV',state.shareSaved ? go('home') : action('save-share'),state.shareSaved ? 'check' : 'copy')}`;
}
function file() {
  return `${nav('文件','home',circle('more',go('record-menu'),'更多操作'))}<div class="scroll"><p class="detail-date">今天 09:28</p><div class="file-preview"><div class="file-paper"><i></i><i></i><i></i><i></i><i></i><i></i></div></div><h3 class="detail-title" style="font-size:20px">王森迪1108.docx</h3><div class="detail-meta"><span class="tag">Word</span><span>82 KB</span></div>${info([['本机内容',state.fileAvailable ? '文件可用' : '暂不可用'],['来源','分享导入']])}</div>${state.fileAvailable ? footer('分享文件',action('share-file'),'share') : footer('返回历史',go('home'),'back')}`;
}

const groups = [
  { id:'history', title:'历史与查找', pages:['home','pinned','search'] },
  { id:'states', title:'开始与空状态', pages:['welcome','empty','no-results'] },
  { id:'details', title:'内容详情', pages:['text-detail','link-detail','image-detail'] },
  { id:'actions', title:'编辑与操作', pages:['edit','image-viewer','record-menu'] },
  { id:'settings', title:'记录设置', pages:['settings','types','recording'] },
  { id:'sync', title:'同步与存储', pages:['sync','storage','appearance'] },
  { id:'keyboard', title:'输入时取用', pages:['keyboard-setup','keyboard','keyboard-system'] },
  { id:'tools', title:'内容工具', pages:['ocr','markdown','json'] },
  { id:'extensions', title:'扩展与预览', pages:['color','share','file'] }
];
const pages = {
  home:{ title:'历史主页', phase:'R1', render:() => home() },
  pinned:{ title:'钉选', phase:'R1', render:() => home('pinned') },
  search:{ title:'搜索', phase:'R1', render:() => home('search') },
  welcome:{ title:'首次启动', phase:'R1', render:welcome },
  empty:{ title:'还没有历史', phase:'R1', render:() => empty() },
  'no-results':{ title:'没有搜索结果', phase:'R1', render:() => empty(true) },
  'text-detail':{ title:'文字详情', phase:'R1', render:textDetail },
  'link-detail':{ title:'链接详情', phase:'R1', render:linkDetail },
  'image-detail':{ title:'图片详情', phase:'R1', render:imageDetail },
  edit:{ title:'编辑记录', phase:'R1', render:edit },
  'image-viewer':{ title:'原图预览', phase:'R1', render:viewer, dark:true },
  'record-menu':{ title:'长按菜单', phase:'R1', render:menu },
  settings:{ title:'设置', phase:'R1', render:settings },
  types:{ title:'记录类型', phase:'R1', render:types },
  recording:{ title:'记录状态', phase:'无浮窗后台模式待验证', render:recording },
  sync:{ title:'iCloud 同步', phase:'R1', render:sync },
  storage:{ title:'历史与空间', phase:'R1', render:storage },
  appearance:{ title:'语言与外观', phase:'R1', render:appearance },
  'keyboard-setup':{ title:'键盘启用指引', phase:'R1 候选', render:keyboardSetup },
  keyboard:{ title:'ClipCV 键盘', phase:'R1 候选 · 模拟聊天应用', render:() => keyboard() },
  'keyboard-system':{ title:'切回常用输入法', phase:'模拟系统键盘', render:() => keyboard(true) },
  ocr:{ title:'图片文字识别', phase:'R2', render:ocr },
  markdown:{ title:'Markdown 预览', phase:'R2', render:markdown },
  json:{ title:'JSON 预览', phase:'R2', render:json },
  color:{ title:'颜色预览', phase:'R2', render:color },
  share:{ title:'分享扩展', phase:'R2 · 模拟系统容器', render:share },
  file:{ title:'文件详情', phase:'R3', render:file }
};

const statusbar = '<div class="statusbar"><span>9:41</span><span class="island"></span><div class="status-icons"><span class="signal"><i></i><i></i><i></i><i></i></span><svg class="icon wifi" viewBox="0 0 24 20"><path d="M2 6q10-8 20 0M6 11q6-5 12 0M10 16q2-2 4 0" stroke-width="2.5"/><circle cx="12" cy="18" r="1" fill="currentColor" stroke="none"/></svg><span class="battery"></span></div></div>';
const pageIDs = groups.flatMap(g => g.pages);

function render() {
  const currentGroup = groups.find(g => g.id === state.group);
  const visible = state.mode === 'preview' ? [state.page] : currentGroup.pages;
  const scrollPositions = new Map($$('.scroll').map(el => [el.closest('[data-page]').dataset.page,el.scrollTop]));
  document.body.classList.toggle('preview-mode',state.mode === 'preview');
  $('#group-nav').innerHTML = groups.map(g => `<button class="${g === currentGroup ? 'active' : ''}" ${action('group',g.id)}>${g.title}</button>`).join('');
  $('#group-index').textContent = String(groups.indexOf(currentGroup) + 1).padStart(2,'0');
  $('#group-title').textContent = currentGroup.title;
  $('#page-progress').textContent = `${groups.indexOf(currentGroup) + 1} / ${groups.length}`;
  $('#board').innerHTML = visible.map(id => {
    const p = pages[id];
    return `<article class="design-panel" data-page="${id}"><div class="screen-caption"><span class="number">${String(pageIDs.indexOf(id) + 1).padStart(2,'0')}</span><strong>${p.title}</strong><span class="phase">${p.phase}</span></div><div class="phone"><div class="screen${p.dark ? ' dark-screen' : ''}${id === 'appearance' && state.appearance === 'dark' ? ' appearance-dark' : ''}">${statusbar}${p.render()}<div class="home-indicator"></div></div></div></article>`;
  }).join('');
  $$('.scroll').forEach(el => { el.scrollTop = scrollPositions.get(el.closest('[data-page]').dataset.page) || 0; });
  $('#page-nav').hidden = state.mode !== 'preview';
  $('#page-nav').innerHTML = state.mode === 'preview' ? pageIDs.map(id => `<button class="${state.page === id ? 'active' : ''}" ${go(id)}>${pages[id].title}</button>`).join('') : '';
  $$('[data-mode]').forEach(b => b.classList.toggle('active',b.dataset.mode === state.mode));
  $$('[data-results]').forEach(updateResultCount);
  renderScenarios();
}
function updateResultCount(el) {
  const count = el.closest('.screen').querySelector('[data-result-count]');
  if (count) count.textContent = $$('[data-id]',el).length;
}
function renderScenarios() {
  $('#scenario-controls')?.remove();
  let content = '';
  if (state.group === 'sync') {
    content = '<span>预览同步状态</span>'+[['enabled','已启用'],['transferring','传输中'],['unavailable','不可用'],['disabled','已关闭']].map(([v,l]) => `<button class="${state.syncStatus === v ? 'active' : ''}" ${action('sync-scenario',v)}>${l}</button>`).join('');
  } else if (state.group === 'extensions') {
    content = `<span>预览文件状态</span><button ${action('file-scenario')} class="active">${state.fileAvailable ? '文件可用' : '文件不可用'}</button>`;
  }
  if (content) $('#board').insertAdjacentHTML('afterend',`<div class="scenario-controls" id="scenario-controls">${content}</div>`);
}
function openPage(id) {
  if (!pages[id]) return;
  state.page = id;
  state.group = groups.find(g => g.pages.includes(id)).id;
  render();
  const phone = $(`[data-page="${id}"] .phone`);
  phone?.classList.add('focus-ring');
  if (!document.body.classList.contains('capture')) phone?.scrollIntoView({block:'nearest',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth'});
  history.replaceState(null,'',`#${id}`);
}
function setGroup(id) {
  const group = groups.find(g => g.id === id);
  if (!group) return;
  state.group = id;
  state.page = group.pages[0];
  render();
  history.replaceState(null,'',`#${group.pages[0]}`);
}
function feedback(button, label = '已复制') {
  if (!button || button.dataset.feedback) return;
  const html = button.innerHTML;
  button.dataset.feedback = 'true';
  button.classList.add('copy-feedback');
  button.innerHTML = icon('check')+(button.classList.contains('primary') ? `<span>${label}</span>` : button.classList.contains('circle-button') ? '' : label);
  setTimeout(() => { if (button.isConnected) { button.innerHTML = html; button.classList.remove('copy-feedback'); delete button.dataset.feedback; } },1100);
}
function toggleSetting(name) {
  if (name === 'sync') state.syncSetting = !state.syncSetting;
  if (name === 'auto') {
    state.autoRecord = !state.autoRecord;
    state.paused = !state.autoRecord;
  }
  if (name.startsWith('type-')) state.types[name.slice(5)] = !state.types[name.slice(5)];
  render();
}
function handleAction(button) {
  const name = button.dataset.action, value = button.dataset.value;
  if (name === 'go') {
    const card = button.closest('[data-id]');
    if (card) state.selected = card.dataset.id;
    openPage(value);
  } else if (name === 'menu' || name === 'edit-item') { state.selected = value; openPage(name === 'menu' ? 'record-menu' : 'edit'); }
  else if (name === 'group') setGroup(value);
  else if (name === 'toggle') toggleSetting(value);
  else if (name === 'filter') { state.filter = value; openPage(value === 'pinned' ? 'pinned' : 'home'); }
  else if (name === 'clear-search') { state.query = ''; state.homeQuery = ''; render(); }
  else if (name === 'pin') {
    const item = state.items.find(i => i.id === value);
    if (item) item.pinned = !item.pinned;
    render();
  } else if (name.startsWith('copy')) feedback(button);
  else if (name === 'save-file') feedback(button,'已存储');
  else if (name === 'pause') { state.paused = !state.paused; state.autoRecord = !state.paused; render(); }
  else if (name === 'start') { state.paused = false; state.autoRecord = true; openPage('home'); }
  else if (name === 'save-edit') {
    const item = state.items.find(i => i.id === value);
    if (item) { item.title = $('#edit-title').value; if ($('#edit-text')) item.text = $('#edit-text').value; state.selected = item.id; }
    openPage(item?.type === 'image' ? 'image-detail' : item?.type === 'link' ? 'link-detail' : 'text-detail');
  } else if (name === 'delete') { state.items = state.items.filter(i => i.id !== value); openPage('home'); }
  else if (name === 'clear-unpinned') { state.items = state.items.filter(i => i.pinned); render(); }
  else if (name === 'clear-all') { state.items = []; render(); }
  else if (name === 'zoom') { state.zoom = Number(value); render(); }
  else if (name === 'appearance') { state.appearance = value; render(); }
  else if (name === 'keyboard-tab') {
    state.keyboardTab = value;
    const keyboard = button.closest('.clip-keyboard');
    $('.snippet-list',keyboard).innerHTML = snippets();
    $$('.keyboard-tabs button',keyboard).forEach(b => b.classList.toggle('active',b.dataset.value === value));
  } else if (name === 'insert') {
    const item = state.items.find(i => i.id === value), screen = button.closest('.screen');
    const input = $('[data-input="draft"]',screen);
    const start = input.selectionStart ?? input.value.length, end = input.selectionEnd ?? start;
    state.draft = input.value.slice(0,start)+item.text+input.value.slice(end);
    input.value = state.draft;
    input.setSelectionRange(start+item.text.length,start+item.text.length);
    feedback($('.insert-button',button));
  } else if (name === 'send') {
    if (!state.draft.trim()) return;
    state.messages.push(state.draft); state.draft = ''; render();
  } else if (name === 'markdown-mode') { state.markdownMode = value; render(); }
  else if (name === 'json-mode') { state.jsonMode = value; render(); }
  else if (name === 'color') { state.color = value; render(); }
  else if (name === 'save-share') { state.shareSaved = true; render(); }
  else if (name === 'file-scenario') { state.fileAvailable = !state.fileAvailable; render(); }
  else if (name === 'sync-scenario') {
    state.syncStatus = value; state.syncActual = value !== 'disabled'; state.syncSetting = state.syncActual; render();
  } else if (name === 'repository' || name === 'open-link') {
    const url = name === 'repository' ? 'https://github.com/wangsendi/ClipCV' : value;
    if (/^https?:\/\//i.test(url)) window.open(url,'_blank','noopener,noreferrer');
  } else if (name.startsWith('share-')) {
    showShareSheet(button);
  }
}
function showShareSheet(button) {
  const screen = button.closest('.screen');
  $('.mock-share',screen)?.remove();
  screen.insertAdjacentHTML('beforeend',`<div class="mock-share"><div class="sheet-handle"></div><div class="sheet-title"><span style="font-size:13px;font-weight:600">分享</span>${circle('x',action('dismiss-share'),'关闭分享面板')}</div><div class="settings-card"><button class="setting-row" ${action('copy')}>${settingIcon('copy')}<span>拷贝</span></button><button class="setting-row" ${action('save-file')}>${settingIcon('file')}<span>存储到文件</span></button></div><p class="note center">系统分享面板示意</p></div>`);
}

document.addEventListener('click', event => {
  const button = event.target.closest('[data-action]');
  if (!button) return;
  if (button.dataset.action === 'dismiss-share') { button.closest('.mock-share').remove(); return; }
  handleAction(button);
});
document.addEventListener('keydown', event => {
  if ((event.key === 'Enter' || event.key === ' ') && event.target.matches('article[data-action]')) {
    event.preventDefault(); handleAction(event.target);
  }
});
document.addEventListener('contextmenu', event => {
  const card = event.target.closest('.history-card[data-id]');
  if (!card) return;
  event.preventDefault(); state.selected = card.dataset.id; openPage('record-menu');
});
document.addEventListener('input', event => {
  const key = event.target.dataset.input;
  if (!key) return;
  if (key === 'draft') { state.draft = event.target.value; return; }
  if (key === 'empty-query') {
    state.query = event.target.value; openPage('search');
    const input = $('[data-page="search"] input'); input.focus(); input.setSelectionRange(input.value.length,input.value.length);
    return;
  }
  if (key === 'query') state.query = event.target.value;
  if (key === 'home-query') state.homeQuery = event.target.value;
  $$('[data-results]').forEach(el => { el.innerHTML = historyResults(el.dataset.results); updateResultCount(el); });
});
document.addEventListener('change', event => {
  if (event.target.dataset.select) { state[event.target.dataset.select] = event.target.value; render(); }
});
$$('[data-mode]').forEach(button => button.addEventListener('click',() => { state.mode = button.dataset.mode; render(); }));
$('#previous-group').addEventListener('click',() => setGroup(groups[(groups.findIndex(g => g.id === state.group)+groups.length-1)%groups.length].id));
$('#next-group').addEventListener('click',() => setGroup(groups[(groups.findIndex(g => g.id === state.group)+1)%groups.length].id));
$('#reset-demo').addEventListener('click',() => location.reload());
window.addEventListener('hashchange',() => { const id = location.hash.slice(1); if (pages[id]) openPage(id); });

const initialPage = location.hash.slice(1);
if (pages[initialPage]) { state.page = initialPage; state.group = groups.find(g => g.pages.includes(initialPage)).id; }
render();

window.clipcvPrototype = { state, groups, pages, setGroup, openPage, render };
