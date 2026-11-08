# _gerar_menu.ps1 - Gerador Sofisticado: Preview PDF/Imagem/Vídeo, Favoritos (LocalStorage) e Breadcrumbs
$ErrorActionPreference = "Stop"
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputFile = Join-Path $baseDir "Menu_Interativo.html"

function Get-TreeData {
    param([string]$Path, [string]$BasePath)
    
    $excluded = @(
        'Menu_Interativo.html',
        'Menu_Interativo_EXEMPLO.html',
        'Atualizar_Menu.bat',
        '_gerar_menu.ps1'
    )

    $items = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | 
             Where-Object { $excluded -notcontains $_.Name } |
             Sort-Object @{Expression={$_.PSIsContainer}; Descending=$true}, Name

    $children = [System.Collections.ArrayList]::new()
    foreach ($item in $items) {
        $relPath = $item.FullName.Substring($BasePath.Length).TrimStart('\', '/')
        
        if ($item.PSIsContainer) {
            $subTree = Get-TreeData -Path $item.FullName -BasePath $BasePath
            [void]$children.Add([PSCustomObject]@{
                name = $item.Name
                type = "folder"
                path = $relPath
                fullPath = $item.FullName
                children = @($subTree)
            })
        } else {
            $ext = $item.Extension.TrimStart('.').ToLower()
            $sizeStr = ""
            if ($item.Length -ge 1GB) { $sizeStr = "{0:N2} GB" -f ($item.Length / 1GB) }
            elseif ($item.Length -ge 1MB) { $sizeStr = "{0:N1} MB" -f ($item.Length / 1MB) }
            elseif ($item.Length -ge 1KB) { $sizeStr = "{0:N1} KB" -f ($item.Length / 1KB) }
            else { $sizeStr = "$($item.Length) B" }
            
            $dateStr = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
            
            # Preview para textos pequenos (evita arquivos grandes de bookmarks)
            $preview = ""
            $isBookmark = ($item.Name -like "o (*).html")
            if ($ext -in @("txt","js","py","css","md","json","xml","csv","bat","ps1") -and $item.Length -lt 30KB -and -not $isBookmark) {
                try {
                    $lines = Get-Content -LiteralPath $item.FullName -TotalCount 25 -Encoding UTF8 -ErrorAction SilentlyContinue
                    if (-not $lines) {
                        $lines = Get-Content -LiteralPath $item.FullName -TotalCount 25 -ErrorAction SilentlyContinue
                    }
                    $preview = ($lines -join "`n")
                } catch { $preview = "" }
            }
            
            [void]$children.Add([PSCustomObject]@{
                name = $item.Name
                type = "file"
                ext = $ext
                size = $sizeStr
                date = $dateStr
                path = $relPath
                fullPath = $item.FullName
                preview = $preview
            })
        }
    }
    return ,@($children)
}

Write-Host "Escaneando pastas em: $baseDir ..."
$tree = Get-TreeData -Path $baseDir -BasePath $baseDir

$jsonString = ConvertTo-Json -InputObject @($tree) -Depth 20 -Compress
$timestamp = Get-Date -Format "dd/MM/yyyy HH:mm"

$htmlTop = @'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>📁 Menu Interativo Pro - Douglas</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
            background: #0d1117; color: #e6edf3;
            height: 100vh; display: flex; flex-direction: column;
            overflow: hidden;
        }

        /* HEADER */
        .header {
            background: linear-gradient(135deg, #161b22, #1f2430);
            padding: 14px 24px; border-bottom: 1px solid #30363d;
            display: flex; align-items: center; gap: 16px; flex-wrap: wrap;
        }
        .header-title-box { display: flex; align-items: center; gap: 10px; }
        .header-title-box h1 { font-size: 1.25em; color: #58a6ff; font-weight: 600; display: flex; align-items: center; gap: 8px; }
        .update-info { font-size: 0.78em; color: #8b949e; margin-left: 8px; font-weight: normal; }

        .search-container { flex: 1; min-width: 250px; position: relative; }
        .search-container input {
            width: 100%; padding: 10px 16px 10px 42px;
            border: 1px solid #30363d; border-radius: 8px;
            background: #0d1117; color: #e6edf3; font-size: 0.92em; transition: all 0.25s;
        }
        .search-container input:focus { outline: none; border-color: #58a6ff; box-shadow: 0 0 0 3px rgba(88,166,255,0.18); }
        .search-container input::placeholder { color: #6e7681; }
        .search-icon { position: absolute; left: 14px; top: 50%; transform: translateY(-50%); color: #6e7681; }

        /* STATS & FILTER BAR */
        .stats-bar {
            display: flex; gap: 8px; padding: 10px 24px;
            background: #161b22; border-bottom: 1px solid #21262d; flex-wrap: wrap; align-items: center;
        }
        .stat-badge {
            display: flex; align-items: center; gap: 6px; padding: 4px 11px;
            border-radius: 14px; font-size: 0.8em; font-weight: 500;
            cursor: pointer; transition: all 0.2s; border: 1px solid transparent; user-select: none;
        }
        .stat-badge:hover { transform: translateY(-1px); }
        .stat-badge.active { border-color: currentColor; box-shadow: 0 0 6px rgba(255,255,255,0.15); }
        .stat-all { background: #21262d; color: #e6edf3; }
        .stat-fav { background: #3c2a10; color: #f2cc60; }
        .stat-pdf { background: #3b1d1d; color: #ff7b72; }
        .stat-img { background: #1d3b2a; color: #7ee787; }
        .stat-txt { background: #1d2d3b; color: #79c0ff; }
        .stat-code { background: #3b3b1d; color: #e3b341; }
        .stat-exe { background: #2d1d3b; color: #d2a8ff; }
        .stat-other { background: #1d2a2a; color: #a5d6ff; }

        /* MAIN CONTENT SPLIT */
        .main-content { display: flex; flex: 1; overflow: hidden; }

        /* TREE PANEL */
        .tree-panel {
            width: 380px; min-width: 280px; border-right: 1px solid #21262d;
            overflow-y: auto; padding: 12px; background: #0d1117;
        }
        .tree-panel::-webkit-scrollbar { width: 6px; }
        .tree-panel::-webkit-scrollbar-thumb { background: #30363d; border-radius: 3px; }
        .tree-item { user-select: none; }
        .tree-label {
            display: flex; align-items: center; gap: 7px; padding: 5px 8px;
            border-radius: 6px; cursor: pointer; transition: all 0.15s; font-size: 0.86em;
        }
        .tree-label:hover { background: #161b22; }
        .tree-label.selected { background: #1f2a3d; color: #58a6ff; font-weight: 600; }
        .tree-label .icon { font-size: 1.05em; flex-shrink: 0; }
        .tree-label .name { flex: 1; word-break: break-word; }
        .tree-label .arrow { font-size: 0.65em; transition: transform 0.2s; color: #6e7681; flex-shrink: 0; }
        .tree-label .arrow.open { transform: rotate(90deg); }
        .tree-children { margin-left: 16px; border-left: 1px solid #21262d; display: none; }
        .tree-children.open { display: block; }
        .tree-label .file-size { font-size: 0.72em; color: #8b949e; margin-left: auto; flex-shrink: 0; }

        /* PREVIEW PANEL */
        .preview-panel {
            flex: 1; overflow-y: auto; padding: 20px 24px; background: #0d1117;
            display: flex; flex-direction: column;
        }
        .tree-panel::-webkit-scrollbar { width: 8px; }
        .tree-panel::-webkit-scrollbar-track { background: #0d1117; }
        .tree-panel::-webkit-scrollbar-thumb { background: #30363d; border-radius: 4px; }
        .tree-panel::-webkit-scrollbar-thumb:hover { background: #58a6ff; }

        .preview-panel::-webkit-scrollbar { width: 10px; }
        .preview-panel::-webkit-scrollbar-track { background: #0d1117; }
        .preview-panel::-webkit-scrollbar-thumb { background: #38434f; border-radius: 5px; }
        .preview-panel::-webkit-scrollbar-thumb:hover { background: #58a6ff; }

        /* BREADCRUMB */
        .breadcrumb-container {
            display: flex; align-items: center; gap: 6px; font-size: 0.82em; color: #8b949e;
            margin-bottom: 14px; flex-wrap: wrap; background: #161b22; padding: 8px 14px;
            border-radius: 8px; border: 1px solid #21262d;
        }
        .breadcrumb-crumb { color: #58a6ff; cursor: pointer; text-decoration: none; }
        .breadcrumb-crumb:hover { text-decoration: underline; }
        .breadcrumb-separator { color: #484f58; font-size: 0.75em; }

        .preview-empty {
            display: flex; flex-direction: column; align-items: center;
            justify-content: center; height: 100%; color: #6e7681; gap: 12px; margin-top: 60px;
        }
        .preview-empty .big-icon { font-size: 3.5em; opacity: 0.3; }

        .preview-card {
            background: #161b22; border: 1px solid #21262d; border-radius: 10px;
            display: flex; flex-direction: column; flex-shrink: 0; min-height: fit-content; margin-bottom: 25px;
        }
        .preview-header {
            padding: 16px 20px; border-bottom: 1px solid #21262d;
            display: flex; align-items: center; gap: 14px;
        }
        .preview-header .icon { font-size: 2.2em; }
        .preview-header .info { flex: 1; }
        .preview-header .info h2 { font-size: 1.15em; color: #e6edf3; margin-bottom: 3px; word-break: break-word; }
        .preview-header .info .path { font-size: 0.78em; color: #8b949e; word-break: break-all; }

        .preview-actions {
            display: flex; gap: 10px; margin-top: 10px; flex-wrap: wrap; align-items: center;
        }
        .btn-action {
            display: inline-flex; align-items: center; gap: 6px;
            padding: 6px 14px; border-radius: 6px; font-size: 0.84em; font-weight: 500;
            text-decoration: none; cursor: pointer; transition: all 0.2s; border: none;
        }
        .btn-open { background: #238636; color: #ffffff; }
        .btn-open:hover { background: #2ea043; color: #ffffff; }
        .btn-copy { background: #21262d; color: #c9d1d9; border: 1px solid #30363d; }
        .btn-copy:hover { background: #30363d; color: #ffffff; }
        .btn-fav { background: #21262d; color: #f2cc60; border: 1px solid #30363d; }
        .btn-fav.active { background: #3c2a10; border-color: #f2cc60; }

        .preview-meta {
            display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
            gap: 10px; padding: 14px 20px; border-bottom: 1px solid #21262d; background: #12161f;
        }
        .meta-item { display: flex; flex-direction: column; gap: 2px; }
        .meta-item .label { font-size: 0.7em; color: #8b949e; text-transform: uppercase; letter-spacing: 0.5px; }
        .meta-item .value { font-size: 0.88em; color: #e6edf3; font-weight: 500; }

        .preview-content { padding: 16px 20px; flex: 1; display: flex; flex-direction: column; }
        .preview-content h3 { font-size: 0.84em; color: #8b949e; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.5px; }

        .preview-text {
            background: #0d1117; border: 1px solid #21262d; border-radius: 8px;
            padding: 14px; font-family: 'Cascadia Code','Consolas',monospace;
            font-size: 0.84em; line-height: 1.6; color: #c9d1d9;
            white-space: pre-wrap; max-height: 380px; overflow-y: auto;
        }

        /* EMBED VIEWER (PDF / IMG / VIDEO) */
        .embed-viewer-container {
            flex: 1; min-height: 480px; width: 100%; display: flex; flex-direction: column;
            border-radius: 8px; overflow: hidden; border: 1px solid #30363d; background: #000;
        }
        .embed-viewer-container iframe, .embed-viewer-container embed {
            width: 100%; height: 100%; min-height: 520px; border: none;
        }
        .embed-image-box {
            display: flex; justify-content: center; align-items: center; padding: 20px;
            background: #0d1117; border-radius: 8px; border: 1px solid #21262d;
        }
        .embed-image-box img {
            max-width: 100%; max-height: 480px; border-radius: 6px; object-fit: contain;
            box-shadow: 0 4px 12px rgba(0,0,0,0.5);
        }
        .embed-video-box video {
            width: 100%; max-height: 480px; border-radius: 6px; outline: none;
        }

        /* FOLDER CONTENTS GRID */
        .folder-contents {
            display: grid; grid-template-columns: repeat(auto-fill, minmax(210px, 1fr)); gap: 8px;
        }
        .folder-item {
            display: flex; align-items: center; gap: 8px; padding: 8px 12px;
            background: #0d1117; border: 1px solid #21262d; border-radius: 8px;
            font-size: 0.84em; transition: all 0.15s; cursor: pointer; text-decoration: none; color: inherit;
        }
        .folder-item:hover { border-color: #58a6ff; background: #1f2a3d; transform: translateY(-1px); }

        .highlight { background: rgba(210,153,34,0.35); color: #e3b341; border-radius: 2px; padding: 0 2px; font-weight: 600; }
        .no-results { text-align: center; padding: 40px; color: #6e7681; }
        .no-results .nr-icon { font-size: 2.8em; margin-bottom: 10px; opacity: 0.3; }

        @media (max-width: 850px) {
            .main-content { flex-direction: column; }
            .tree-panel { width: 100%; min-width: auto; max-height: 38vh; border-right: none; border-bottom: 1px solid #21262d; }
        }
    </style>
</head>
<body>
<div class="header">
    <div class="header-title-box">
        <h1><span>📁</span> Explorador de Arquivos</h1>
        <span class="update-info">Atualizado: __TIMESTAMP__</span>
    </div>
    <div class="search-container">
        <span class="search-icon">🔍</span>
        <input type="text" id="searchInput" placeholder="Pesquisar por nome, matéria, código..." autofocus>
    </div>
</div>

<div class="stats-bar" id="statsBar"></div>

<div class="main-content">
    <div class="tree-panel" id="treePanel"></div>
    <div class="preview-panel" id="previewPanel">
        <div class="preview-empty">
            <div class="big-icon">📂</div>
            <p>Selecione um arquivo ou pasta para ver os detalhes</p>
            <p style="font-size:0.82em;color:#484f58;">Preview de PDF, Imagens, Textos e Abertura Direta</p>
        </div>
    </div>
</div>

<script>
const fileTree = __RAW_JSON__;
'@

$htmlBottom = @'
const extIcons = {
    pdf:"📕",txt:"📝",js:"🟨",py:"🐍",html:"🌐",css:"🎨",md:"📘",json:"📋",xml:"📋",csv:"📊",
    png:"🖼️",jpg:"🖼️",jpeg:"🖼️",gif:"🖼️",bmp:"🖼️",svg:"🖼️",webp:"🖼️",
    exe:"⚙️",msi:"⚙️",bat:"⚙️",ps1:"⚙️",msixbundle:"⚙️",
    zip:"📦","7z":"📦",rar:"📦",gz:"📦",tar:"📦",
    mp4:"🎬",avi:"🎬",mkv:"🎬",mov:"🎬",wmv:"🎬",
    mp3:"🎵",wav:"🎵",flac:"🎵",
    doc:"📄",docx:"📄",xls:"📊",xlsx:"📊",ppt:"📊",pptx:"📊",rtf:"📄",
    vmdk:"💿",vmx:"💿",vmxf:"💿",nvram:"💿",vmsd:"💿",scoreboard:"💿",log:"📋"
};
const extCats = {
    pdf:"pdf",txt:"txt",md:"txt",rtf:"txt",doc:"txt",docx:"txt",csv:"txt",
    js:"code",py:"code",html:"code",css:"code",json:"code",xml:"code",bat:"code",ps1:"code",
    png:"img",jpg:"img",jpeg:"img",gif:"img",bmp:"img",svg:"img",webp:"img",
    mp4:"video",avi:"video",mkv:"video",mov:"video",wmv:"video",
    exe:"exe",msi:"exe",msixbundle:"exe"
};
const catLabels = {
    all:{emoji:"📂",label:"Todos"},
    fav:{emoji:"⭐",label:"Favoritos"},
    pdf:{emoji:"📕",label:"PDFs"},
    img:{emoji:"🖼️",label:"Imagens"},
    txt:{emoji:"📝",label:"Textos"},
    code:{emoji:"💻",label:"Código"},
    exe:{emoji:"⚙️",label:"Executáveis"},
    other:{emoji:"📎",label:"Outros"}
};

// Favoritos em LocalStorage
let favorites = [];
try {
    favorites = JSON.parse(localStorage.getItem("douglas_file_favorites") || "[]");
} catch(e) { favorites = []; }

function toggleFavorite(path) {
    if(favorites.includes(path)) {
        favorites = favorites.filter(p => p !== path);
    } else {
        favorites.push(path);
    }
    localStorage.setItem("douglas_file_favorites", JSON.stringify(favorites));
    renderStats();
    renderTree();
    const cur = findNodeByPath(fileTree, path);
    if(cur) showPreview(cur);
}

function isFav(path) {
    return favorites.includes(path);
}

function getChildren(item) {
    if (!item || !item.children) return [];
    return Array.isArray(item.children) ? item.children : [item.children];
}

function getIcon(i){return i.type==="folder"?"📁":(extIcons[i.ext]||"📄")}
function getCat(ext){return extCats[ext]||"other"}

function countFiles(nodes){
    const c={all:0,fav:favorites.length,pdf:0,img:0,txt:0,code:0,exe:0,other:0};
    function w(list){
        if(!list) return;
        const arr = Array.isArray(list) ? list : [list];
        arr.forEach(n=>{
            if(n.type==="file"){
                c.all++;
                const cat = getCat(n.ext);
                if(c[cat] !== undefined) c[cat] = (c[cat] || 0) + 1;
                else c.other = (c.other || 0) + 1;
            }
            if(n.children) w(getChildren(n));
        });
    }
    w(nodes);
    return c;
}

let activeFilter="all",searchTerm="",selectedEl=null;

function renderStats(){
    const c=countFiles(fileTree),bar=document.getElementById("statsBar");bar.innerHTML="";
    Object.keys(catLabels).forEach(cat=>{
        const b=document.createElement("div");
        b.className="stat-badge stat-"+cat+(activeFilter===cat?" active":"");
        b.innerHTML=catLabels[cat].emoji+" "+catLabels[cat].label+": <strong>"+(c[cat]||0)+"</strong>";
        b.onclick=()=>{activeFilter=cat;renderStats();renderTree()};bar.appendChild(b);
    });
}

function matchSearch(n){return!searchTerm||n.toLowerCase().includes(searchTerm.toLowerCase())}

function matchFilter(i){
    if(activeFilter==="all") return true;
    if(i.type==="folder") return true;
    if(activeFilter==="fav") return isFav(i.path);
    return getCat(i.ext)===activeFilter;
}

function hasVisible(n){
    if(n.type==="file") return matchSearch(n.name) && matchFilter(n);
    const ch = getChildren(n);
    if(!ch || ch.length === 0) return false;
    return ch.some(c=>hasVisible(c));
}

function hl(t){
    if(!searchTerm)return t;
    const escaped = searchTerm.replace(/[.*+?^${}()|[\]\\]/g,"\\$&");
    return t.replace(new RegExp("("+escaped+")","gi"),'<span class="highlight">$1</span>');
}

function openFile(path) {
    const safeUrl = encodeURI(path.replace(/\\/g, "/"));
    window.open(safeUrl, "_blank");
}

function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
        alert("Caminho copiado para a área de transferência:\n" + text);
    }).catch(() => {
        prompt("Copie o caminho do arquivo:", text);
    });
}

function buildBreadcrumb(path) {
    if(!path) return "";
    const parts = path.split(/[\\\/]/);
    let html = '<div class="breadcrumb-container"><span style="font-size:1.1em">🧭</span> ';
    let accum = "";
    parts.forEach((p, idx) => {
        accum += (idx === 0 ? "" : "\\") + p;
        const currentPath = accum;
        if(idx === parts.length - 1) {
            html += `<span style="color:#e6edf3;font-weight:600">${esc(p)}</span>`;
        } else {
            html += `<a class="breadcrumb-crumb" onclick="selectAndShow('${esc(currentPath).replace(/\\/g,"\\\\")}')">${esc(p)}</a> <span class="breadcrumb-separator">/</span> `;
        }
    });
    html += '</div>';
    return html;
}

function renderTree(){
    const p=document.getElementById("treePanel");p.innerHTML="";let any=false;
    function mk(item,d){
        if(!hasVisible(item))return null;
        const div=document.createElement("div");div.className="tree-item";
        const lbl=document.createElement("div");lbl.className="tree-label";lbl.style.paddingLeft=(d*16+8)+"px";
        const ch = getChildren(item);

        if(item.type==="folder"){
            const a=document.createElement("span");
            a.className="arrow"+(searchTerm || activeFilter!=="all"?" open":"");
            a.textContent="▶";
            lbl.appendChild(a);
        }
        const ic=document.createElement("span");ic.className="icon";
        ic.textContent = (item.type==="file" && isFav(item.path)) ? "⭐" : getIcon(item);
        lbl.appendChild(ic);

        const nm=document.createElement("span");nm.className="name";nm.innerHTML=hl(item.name);lbl.appendChild(nm);
        if(item.size){const s=document.createElement("span");s.className="file-size";s.textContent=item.size;lbl.appendChild(s)}
        div.appendChild(lbl);

        if(item.type==="folder"&&ch.length>0){
            const chDiv=document.createElement("div");chDiv.className="tree-children"+(searchTerm || activeFilter!=="all"?" open":"");
            ch.forEach(c=>{const n=mk(c,d+1);if(n)chDiv.appendChild(n)});
            div.appendChild(chDiv);
            lbl.onclick=()=>{
                const a=lbl.querySelector(".arrow");
                if(a) a.classList.toggle("open");
                chDiv.classList.toggle("open");
                showPreview(item);
                if(selectedEl) selectedEl.classList.remove("selected");
                lbl.classList.add("selected");
                selectedEl=lbl;
            };
        } else {
            lbl.onclick=()=>{
                showPreview(item);
                if(selectedEl) selectedEl.classList.remove("selected");
                lbl.classList.add("selected");
                selectedEl=lbl;
            };
            lbl.ondblclick=()=>{
                if(item.type==="file") openFile(item.path);
            };
        }
        return div;
    }
    const rootList = Array.isArray(fileTree) ? fileTree : [fileTree];
    rootList.forEach(c=>{const n=mk(c,0);if(n){p.appendChild(n);any=true}});
    if(!any)p.innerHTML='<div class="no-results"><div class="nr-icon">🔍</div><p>Nenhum resultado para os filtros aplicados</p></div>';
}

function esc(s){if(!s)return"";return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;")}

function showPreview(item){
    const p=document.getElementById("previewPanel");
    const breadcrumb = buildBreadcrumb(item.path);

    if(item.type==="folder"){
        const ch=getChildren(item),fi=ch.filter(c=>c.type==="file"),fo=ch.filter(c=>c.type==="folder");
        p.innerHTML= breadcrumb + `
            <div class="preview-card">
                <div class="preview-header">
                    <span class="icon">📁</span>
                    <div class="info">
                        <h2>${esc(item.name)}</h2>
                        <p class="path">${esc(item.path)}</p>
                        <div class="preview-actions">
                            <button class="btn-action btn-copy" onclick="copyToClipboard('${esc(item.fullPath).replace(/\\/g,"\\\\")}')">📋 Copiar Caminho Completo</button>
                        </div>
                    </div>
                </div>
                ${ch.length ? `
                <div class="preview-content">
                    <h3>Conteúdo da Pasta (${fo.length} pastas, ${fi.length} arquivos)</h3>
                    <div class="folder-contents">
                        ${ch.map(c=>`
                            <div class="folder-item" onclick="selectAndShow('${esc(c.path).replace(/\\/g,"\\\\")}')">
                                <span>${getIcon(c)}</span>
                                <span>${esc(c.name)}</span>
                            </div>
                        `).join("")}
                    </div>
                </div>` : ''}
            </div>
        `;
        return;
    }

    const safeUrl = encodeURI(item.path.replace(/\\/g, "/"));
    const favActive = isFav(item.path);

    let viewerHtml = "";
    const cat = getCat(item.ext);

    if(cat === "pdf") {
        viewerHtml = `
            <div class="preview-content">
                <h3>📖 Visualizador de PDF Embutido</h3>
                <div class="embed-viewer-container">
                    <iframe src="${safeUrl}#toolbar=1" type="application/pdf"></iframe>
                </div>
            </div>
        `;
    } else if(cat === "img") {
        viewerHtml = `
            <div class="preview-content">
                <h3>🖼️ Imagem em Alta Resolução</h3>
                <div class="embed-image-box">
                    <img src="${safeUrl}" alt="${esc(item.name)}" />
                </div>
            </div>
        `;
    } else if(cat === "video") {
        viewerHtml = `
            <div class="preview-content">
                <h3>🎬 Reprodução de Vídeo</h3>
                <div class="embed-video-box">
                    <video controls src="${safeUrl}"></video>
                </div>
            </div>
        `;
    } else if(item.preview) {
        viewerHtml = `
            <div class="preview-content">
                <h3>📄 Preview do Conteúdo</h3>
                <div class="preview-text">${esc(item.preview)}</div>
            </div>
        `;
    }

    p.innerHTML = breadcrumb + `
        <div class="preview-card">
            <div class="preview-header">
                <span class="icon">${getIcon(item)}</span>
                <div class="info">
                    <h2>${esc(item.name)}</h2>
                    <p class="path">${esc(item.path)}</p>
                    <div class="preview-actions">
                        <a class="btn-action btn-open" href="${safeUrl}" target="_blank">🚀 Abrir em Nova Aba</a>
                        <button class="btn-action btn-fav ${favActive ? 'active' : ''}" onclick="toggleFavorite('${esc(item.path).replace(/\\/g,"\\\\")}')">
                            ${favActive ? '⭐ Favorito Salvo' : '☆ Marcar como Favorito'}
                        </button>
                        <button class="btn-action btn-copy" onclick="copyToClipboard('${esc(item.fullPath).replace(/\\/g,"\\\\")}')">📋 Copiar Caminho</button>
                    </div>
                </div>
            </div>
            <div class="preview-meta">
                <div class="meta-item"><span class="label">Extensão</span><span class="value">.${esc(item.ext?item.ext.toUpperCase():"—")}</span></div>
                <div class="meta-item"><span class="label">Tamanho</span><span class="value">${item.size||"—"}</span></div>
                <div class="meta-item"><span class="label">Data Modificação</span><span class="value">${item.date||"—"}</span></div>
                <div class="meta-item"><span class="label">Categoria</span><span class="value">${(catLabels[getCat(item.ext)]||catLabels.other).label}</span></div>
            </div>
            ${viewerHtml}
        </div>
    `;
}

function findNodeByPath(nodes, path) {
    const list = Array.isArray(nodes) ? nodes : [nodes];
    for(const n of list) {
        if(n.path === path) return n;
        if(n.children) {
            const found = findNodeByPath(n.children, path);
            if(found) return found;
        }
    }
    return null;
}

function selectAndShow(path) {
    const node = findNodeByPath(fileTree, path);
    if(node) {
        showPreview(node);
    }
}

document.getElementById("searchInput").addEventListener("input",e=>{searchTerm=e.target.value.trim();renderTree()});
renderStats();
renderTree();
</script>
</body>
</html>
'@

$topReplaced = $htmlTop.Replace("__TIMESTAMP__", $timestamp).Replace("__RAW_JSON__", $jsonString)
$fullHtml = $topReplaced + "`n" + $htmlBottom

$utf8Encoding = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($outputFile, $fullHtml, $utf8Encoding)

Write-Host "Menu Pro gerado com sucesso em: $outputFile"
