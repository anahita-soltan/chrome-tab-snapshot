-- =============================================================================
--  Chrome Tab Collector
--  Author: https://github.com/YOUR_USERNAME
--
--  What it does:
--    Reads every open tab from every Google Chrome window, then generates
--    a self-contained interactive HTML file and opens it in your browser.
--
--  Features of the generated HTML viewer:
--    • View tabs grouped by Window or by Domain
--    • Live search across all tab titles and URLs
--    • Click any tab's "Open ↗" link to jump straight to it
--    • Domain jump bar for quick filtering when in Domain mode
--    • Copy URLs to clipboard — per group or all at once
--    • Expand / Collapse individual sections or all at once
--    • Stats summary: total windows, tabs, and unique domains
--
--  Requirements:
--    • macOS with Google Chrome open
--    • Script Editor (built into macOS — find it via Spotlight)
--    • Grant Automation permission to Script Editor when prompted
--
--  Usage:
--    1. Open Script Editor (⌘Space → "Script Editor")
--    2. Paste this script and click Run ▶
--    3. Allow Chrome access if macOS asks
--    4. TabCollector.html opens automatically in your default browser
--       (file is also saved to your Desktop)
-- =============================================================================


-- =============================================================================
--  STEP 1 — Collect tab data from Chrome
--
--  We talk to Chrome via AppleScript's built-in scripting dictionary.
--  Each window contains a list of tabs; each tab exposes a title and URL.
--  We build a JSON array string by hand (no external libraries needed).
-- =============================================================================

tell application "Google Chrome"
	set allWindows to windows
	set windowCount to count of allWindows

	-- Start building a JSON array: [ {window, tabs: [...]}, ... ]
	set tabData to "["
	set windowNum to 0

	repeat with w in allWindows
		set windowNum to windowNum + 1
		set tabData to tabData & "{\"window\":" & windowNum & ",\"tabs\":["

		set tabList to tabs of w
		set tabNum to 0

		repeat with t in tabList
			set tabNum to tabNum + 1
			set tabTitle to title of t
			set tabURL to URL of t

			-- Escape backslashes first, then double-quotes, so the strings
			-- are safe to embed inside a JavaScript string literal.
			set tabTitle to my replaceText(tabTitle, "\\", "\\\\")
			set tabTitle to my replaceText(tabTitle, "\"", "\\\"")
			set tabURL to my replaceText(tabURL, "\\", "\\\\")
			set tabURL to my replaceText(tabURL, "\"", "\\\"")

			set tabData to tabData & "{\"title\":\"" & tabTitle & "\",\"url\":\"" & tabURL & "\"}"

			-- Add a comma between tab entries (not after the last one)
			if tabNum < (count of tabList) then set tabData to tabData & ","
		end repeat

		set tabData to tabData & "]}"

		-- Add a comma between window entries (not after the last one)
		if windowNum < windowCount then set tabData to tabData & ","
	end repeat

	set tabData to tabData & "]"
end tell


-- =============================================================================
--  STEP 2 — Build the HTML viewer
--
--  Everything below is a single self-contained HTML file:
--    • Google Fonts (Syne + DM Mono) loaded from CDN
--    • All CSS inlined in <style>
--    • The tab data from Step 1 embedded as a JS constant (RAW)
--    • All interactivity in vanilla JS — no frameworks, no dependencies
--
--  The file works offline after the first load; only favicons and fonts
--  require a network connection.
-- =============================================================================

-- Stamp the generation time using the shell (no Date libraries needed)
set generatedAt to do shell script "date '+%B %d, %Y at %H:%M'"

set htmlContent to "<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <title>Tab Collector</title>

  <!-- Syne: display headings | DM Mono: body / code / UI text -->
  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">
  <link href=\"https://fonts.googleapis.com/css2?family=Syne:wght@400;600;700;800&family=DM+Mono:wght@300;400;500&display=swap\" rel=\"stylesheet\">

  <style>
    /* ── Reset ───────────────────────────────────────────────────────────── */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    /* ── Design tokens ───────────────────────────────────────────────────── */
    :root {
      --bg:       #0d0d0f;   /* page background           */
      --surface:  #151518;   /* card / panel background   */
      --surface2: #1c1c21;   /* hover state on surfaces   */
      --border:   #2a2a32;   /* subtle borders             */
      --accent:   #c8f04a;   /* primary accent (green)    */
      --accent2:  #7b61ff;   /* secondary accent (purple) */
      --text:     #e8e8f0;   /* primary text               */
      --muted:    #6b6b80;   /* secondary / label text    */
      --tag-bg:   #1e1e28;   /* domain tag background     */
    }

    /* ── Base ────────────────────────────────────────────────────────────── */
    body {
      background: var(--bg);
      color: var(--text);
      font-family: 'DM Mono', monospace;
      min-height: 100vh;
      overflow-x: hidden;
    }

    /* Decorative ambient glows (purple top-left, green bottom-right) */
    body::before, body::after {
      content: '';
      position: fixed;
      pointer-events: none;
      z-index: 0;
    }
    body::before {
      top: -30%; left: -20%; width: 60%; height: 60%;
      background: radial-gradient(ellipse, rgba(123,97,255,0.08) 0%, transparent 70%);
    }
    body::after {
      bottom: -20%; right: -10%; width: 50%; height: 50%;
      background: radial-gradient(ellipse, rgba(200,240,74,0.06) 0%, transparent 70%);
    }

    /* ── Layout ──────────────────────────────────────────────────────────── */
    .app {
      position: relative;
      z-index: 1;
      max-width: 1100px;
      margin: 0 auto;
      padding: 48px 24px 80px;
    }

    /* ── Header ──────────────────────────────────────────────────────────── */
    header { margin-bottom: 48px; }

    .logo { display: flex; align-items: center; gap: 12px; margin-bottom: 8px; }
    .logo-icon {
      width: 36px; height: 36px;
      background: var(--accent); border-radius: 8px;
      display: flex; align-items: center; justify-content: center;
      font-size: 18px; flex-shrink: 0;
    }
    h1 {
      font-family: 'Syne', sans-serif;
      font-size: clamp(28px, 5vw, 42px);
      font-weight: 800; letter-spacing: -1px; line-height: 1;
    }
    h1 span { color: var(--accent); }
    .subtitle { color: var(--muted); font-size: 13px; margin-top: 8px; }

    /* ── Stats strip ─────────────────────────────────────────────────────── */
    .stats { display: flex; gap: 24px; flex-wrap: wrap; margin-top: 24px; }
    .stat {
      background: var(--surface); border: 1px solid var(--border);
      border-radius: 10px; padding: 14px 20px;
    }
    .stat-num {
      font-family: 'Syne', sans-serif;
      font-size: 28px; font-weight: 800;
      color: var(--accent); line-height: 1;
    }
    .stat-label {
      font-size: 11px; color: var(--muted);
      margin-top: 4px; letter-spacing: 0.08em; text-transform: uppercase;
    }

    /* ── Control bar ─────────────────────────────────────────────────────── */
    .controls {
      display: flex; gap: 10px;
      align-items: center; flex-wrap: wrap;
      margin-bottom: 32px;
    }

    /* Search field with inset magnifier icon */
    .search-wrap { position: relative; flex: 1; min-width: 200px; max-width: 380px; }
    .search-wrap input {
      width: 100%;
      background: var(--surface); border: 1px solid var(--border);
      color: var(--text); font-family: 'DM Mono', monospace; font-size: 13px;
      padding: 10px 14px 10px 38px; border-radius: 8px;
      outline: none; transition: border-color 0.2s;
    }
    .search-wrap input:focus       { border-color: var(--accent2); }
    .search-wrap input::placeholder { color: var(--muted); }
    .search-wrap .icon {
      position: absolute; left: 12px; top: 50%; transform: translateY(-50%);
      color: var(--muted); font-size: 14px; pointer-events: none;
    }

    /* Generic button style shared by all toolbar buttons */
    .btn {
      background: var(--surface); border: 1px solid var(--border);
      color: var(--text); font-family: 'DM Mono', monospace; font-size: 12px;
      padding: 9px 14px; border-radius: 8px;
      cursor: pointer; transition: all 0.15s; white-space: nowrap;
    }
    .btn:hover  { border-color: var(--accent2); color: var(--accent); }
    .btn.active { background: var(--accent); color: #000; border-color: var(--accent); font-weight: 500; }
    .btn-group  { display: flex; gap: 6px; }

    /* ── Domain jump bar (Domain mode only) ──────────────────────────────── */
    .group-bar {
      display: flex; gap: 8px; flex-wrap: wrap;
      margin-bottom: 28px; align-items: center;
    }
    .group-bar-label {
      font-size: 11px; color: var(--muted);
      text-transform: uppercase; letter-spacing: 0.1em; margin-right: 4px;
    }
    .group-chip {
      background: var(--tag-bg); border: 1px solid var(--border);
      color: var(--muted); font-size: 12px;
      padding: 5px 12px; border-radius: 20px;
      cursor: pointer; transition: all 0.15s;
      font-family: 'DM Mono', monospace;
    }
    .group-chip:hover,
    .group-chip.active { background: var(--accent2); border-color: var(--accent2); color: #fff; }

    /* ── Section cards (one per window or domain) ────────────────────────── */
    .section {
      margin-bottom: 20px;
      border: 1px solid var(--border); border-radius: 14px;
      overflow: hidden; background: var(--surface);
    }
    .section-header {
      display: flex; align-items: center; justify-content: space-between;
      padding: 14px 20px; gap: 12px;
      cursor: pointer; user-select: none;
      border-bottom: 1px solid var(--border);
      transition: background 0.15s;
    }
    .section-header:hover { background: var(--surface2); }

    .section-title {
      font-family: 'Syne', sans-serif;
      font-weight: 700; font-size: 15px;
      display: flex; align-items: center; gap: 10px;
    }
    /* Pill badge showing the tab count for this section */
    .section-title .badge {
      background: var(--accent); color: #000;
      font-size: 11px; font-family: 'DM Mono', monospace;
      font-weight: 500; padding: 2px 8px; border-radius: 20px;
    }

    .section-actions { display: flex; gap: 8px; align-items: center; }
    .copy-all-btn {
      background: transparent; border: 1px solid var(--border);
      color: var(--muted); font-size: 11px;
      font-family: 'DM Mono', monospace;
      padding: 4px 10px; border-radius: 6px;
      cursor: pointer; transition: all 0.15s;
    }
    .copy-all-btn:hover { border-color: var(--accent); color: var(--accent); }

    /* Chevron rotates when section is collapsed */
    .chevron { color: var(--muted); font-size: 12px; transition: transform 0.2s; flex-shrink: 0; }
    .section.collapsed .chevron      { transform: rotate(-90deg); }
    .section.collapsed .section-body { display: none; }

    /* Brief summary shown in the header while collapsed */
    .collapsed-hint { padding: 10px 20px; color: var(--muted); font-size: 12px; display: none; }
    .section.collapsed .collapsed-hint { display: block; }

    /* ── Tab rows ────────────────────────────────────────────────────────── */
    .tab-row {
      display: flex; align-items: center; gap: 12px;
      padding: 10px 20px;
      border-bottom: 1px solid var(--border);
      transition: background 0.1s;
      animation: fadeIn 0.2s ease both;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(4px); }
      to   { opacity: 1; transform: none; }
    }
    .tab-row:last-child { border-bottom: none; }
    .tab-row:hover      { background: var(--surface2); }

    /* 16×16 site favicon fetched from Google's favicon service */
    .favicon { width: 16px; height: 16px; flex-shrink: 0; border-radius: 3px; }

    .tab-info  { flex: 1; min-width: 0; }
    .tab-title {
      font-size: 13px; color: var(--text);
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }
    .tab-url {
      font-size: 11px; color: var(--muted); margin-top: 2px;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }

    /* Domain pill — hidden by default, revealed in Domain grouping mode */
    .tab-domain-tag {
      background: var(--tag-bg); border: 1px solid var(--border);
      color: var(--muted); font-size: 10px;
      padding: 2px 8px; border-radius: 20px;
      white-space: nowrap; flex-shrink: 0; display: none;
    }
    .showing-domain .tab-domain-tag { display: inline-block; }

    /* Link to open the tab in a new browser tab */
    .tab-link {
      color: var(--accent2); text-decoration: none;
      font-size: 11px; flex-shrink: 0;
      padding: 4px 8px; border-radius: 6px;
      transition: background 0.15s;
    }
    .tab-link:hover { background: rgba(123,97,255,0.15); }

    /* ── Empty search state ──────────────────────────────────────────────── */
    .empty { text-align: center; padding: 48px 24px; color: var(--muted); font-size: 14px; }

    /* ── Toast notification ──────────────────────────────────────────────── */
    .toast {
      position: fixed; bottom: 24px; right: 24px;
      background: var(--accent); color: #000;
      font-family: 'DM Mono', monospace; font-size: 13px;
      padding: 10px 18px; border-radius: 10px;
      opacity: 0; transform: translateY(8px);
      transition: all 0.2s; pointer-events: none; z-index: 100;
    }
    .toast.show { opacity: 1; transform: none; }
  </style>
</head>

<body>
<div class=\"app\">

  <!-- ── Header ──────────────────────────────────────────────────────────── -->
  <header>
    <div class=\"logo\">
      <div class=\"logo-icon\">⬡</div>
      <h1>Tab <span>Collector</span></h1>
    </div>
    <p class=\"subtitle\">Generated " & generatedAt & "</p>
    <!-- Stat cards injected by renderStats() on load -->
    <div class=\"stats\" id=\"stats\"></div>
  </header>

  <!-- ── Toolbar ─────────────────────────────────────────────────────────── -->
  <div class=\"controls\">
    <div class=\"search-wrap\">
      <span class=\"icon\">⌕</span>
      <input type=\"text\" id=\"search\" placeholder=\"Search tabs...\" oninput=\"filterTabs()\">
    </div>
    <div class=\"btn-group\">
      <button class=\"btn active\" id=\"btn-window\" onclick=\"setGroupMode('window')\">By Window</button>
      <button class=\"btn\"        id=\"btn-domain\" onclick=\"setGroupMode('domain')\">By Domain</button>
    </div>
    <button class=\"btn\" onclick=\"toggleAll(true)\">Expand All</button>
    <button class=\"btn\" onclick=\"toggleAll(false)\">Collapse All</button>
    <button class=\"btn\" onclick=\"copyAllUrls()\">Copy All URLs</button>
  </div>

  <!-- ── Domain jump bar (rendered only in Domain mode) ──────────────────── -->
  <div class=\"group-bar\" id=\"group-bar\" style=\"display:none\"></div>

  <!-- ── Main section cards (injected by render()) ───────────────────────── -->
  <div id=\"container\"></div>

</div>

<!-- Clipboard confirmation toast -->
<div class=\"toast\" id=\"toast\"></div>


<script>
  // ── Data ──────────────────────────────────────────────────────────────────
  // RAW is the JSON array built by AppleScript:
  //   [ { window: N, tabs: [ { title, url }, ... ] }, ... ]
  const RAW = " & tabData & ";

  // ── State ─────────────────────────────────────────────────────────────────
  let groupMode    = 'window'; // 'window' | 'domain'
  let activeFilter = null;     // active domain chip filter, or null
  let searchQuery  = '';       // current search string

  // ── Utility helpers ───────────────────────────────────────────────────────

  /** Return the bare hostname (no www.) from a URL, or 'other' on failure. */
  function getDomain(url) {
    try { return new URL(url).hostname.replace(/^www\\./, '') || 'other'; }
    catch { return 'other'; }
  }

  /** Build a Google-hosted favicon URL for a given page URL. */
  function getFaviconUrl(url) {
    try { return `https://www.google.com/s2/favicons?domain=${encodeURIComponent(new URL(url).origin)}&sz=32`; }
    catch { return ''; }
  }

  /** Escape a string so it is safe to inject into HTML attributes or text. */
  function escapeHtml(s) {
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;');
  }

  // ── Build flat tab list ───────────────────────────────────────────────────
  // Flatten the nested windows → tabs structure into a single array so that
  // filtering and grouping work against a uniform data set.
  const allTabs = [];
  RAW.forEach((w, wi) => {
    w.tabs.forEach(t => {
      allTabs.push({
        window: wi + 1,          // 1-based window number for display
        domain: getDomain(t.url),
        title:  t.title,
        url:    t.url,
        idx:    allTabs.length,  // stable index used as DOM key
      });
    });
  });

  // ── renderStats ───────────────────────────────────────────────────────────
  /** Inject the three summary stat cards (Windows / Tabs / Domains). */
  function renderStats() {
    const uniqueDomains = new Set(allTabs.map(t => t.domain)).size;
    document.getElementById('stats').innerHTML = `
      <div class=\"stat\"><div class=\"stat-num\">${RAW.length}</div><div class=\"stat-label\">Windows</div></div>
      <div class=\"stat\"><div class=\"stat-num\">${allTabs.length}</div><div class=\"stat-label\">Total Tabs</div></div>
      <div class=\"stat\"><div class=\"stat-num\">${uniqueDomains}</div><div class=\"stat-label\">Unique Domains</div></div>
    `;
  }

  // ── render ────────────────────────────────────────────────────────────────
  /**
   * Main render — rebuilds #container from scratch based on the three
   * state variables: groupMode, activeFilter, searchQuery.
   */
  function render() {
    const container = document.getElementById('container');
    const query = searchQuery.toLowerCase();

    // 1. Filter — apply live search and any active domain/window chip
    const visible = allTabs.filter(t => {
      const matchSearch = !query
        || t.title.toLowerCase().includes(query)
        || t.url.toLowerCase().includes(query);
      const matchFilter = !activeFilter || (
        groupMode === 'window' ? t.window === activeFilter : t.domain === activeFilter
      );
      return matchSearch && matchFilter;
    });

    // 2. Group — bucket visible tabs by window number or domain
    let groups = [];
    if (groupMode === 'window') {
      const map = {};
      visible.forEach(t => {
        if (!map[t.window]) map[t.window] = { label: `Window ${t.window}`, key: t.window, tabs: [] };
        map[t.window].tabs.push(t);
      });
      groups = Object.values(map);
    } else {
      const map = {};
      visible.forEach(t => {
        if (!map[t.domain]) map[t.domain] = { label: t.domain, key: t.domain, tabs: [] };
        map[t.domain].tabs.push(t);
      });
      // Busiest domains first
      groups = Object.values(map).sort((a, b) => b.tabs.length - a.tabs.length);
    }

    // 3. Empty state
    if (groups.length === 0) {
      container.innerHTML = '<div class=\"empty\">No tabs match your search.</div>';
      return;
    }

    // 4. Render section cards
    container.innerHTML = groups.map((g, gi) => `
      <div class=\"section\" id=\"sec-${gi}\">

        <!-- Clickable header: collapses/expands the section -->
        <div class=\"section-header\" onclick=\"toggleSection(${gi})\">
          <div class=\"section-title\">
            ${escapeHtml(g.label)}
            <span class=\"badge\">${g.tabs.length}</span>
          </div>
          <div class=\"section-actions\">
            <button class=\"copy-all-btn\"
                    onclick=\"event.stopPropagation(); copyGroupUrls(${gi})\">Copy URLs</button>
            <span class=\"chevron\">▾</span>
          </div>
        </div>

        <!-- Shown inside the header when section is collapsed -->
        <div class=\"collapsed-hint\">${g.tabs.length} tabs hidden</div>

        <!-- Individual tab rows -->
        <div class=\"section-body\">
          ${g.tabs.map(t => `
            <div class=\"tab-row\" data-idx=\"${t.idx}\">
              <img class=\"favicon\"
                   src=\"${getFaviconUrl(t.url)}\"
                   onerror=\"this.style.display='none'\"
                   loading=\"lazy\">
              <div class=\"tab-info\">
                <div class=\"tab-title\">${escapeHtml(t.title)}</div>
                <div class=\"tab-url\">${escapeHtml(t.url)}</div>
              </div>
              <!-- Domain pill: only visible when in Domain grouping mode -->
              <span class=\"tab-domain-tag\">${escapeHtml(t.domain)}</span>
              <a class=\"tab-link\" href=\"${escapeHtml(t.url)}\" target=\"_blank\">Open ↗</a>
            </div>
          `).join('')}
        </div>

      </div>
    `).join('');

    // Stash groups so clipboard handlers can look up tabs by section index
    window._groups = groups;
  }

  // ── renderGroupBar ────────────────────────────────────────────────────────
  /**
   * Rebuild the domain jump bar shown only in Domain mode.
   * Displays the top 12 domains by tab count as clickable filter chips.
   */
  function renderGroupBar() {
    const bar = document.getElementById('group-bar');
    if (groupMode !== 'domain') {
      bar.style.display = 'none';
      activeFilter = null;
      return;
    }

    // Count tabs per domain across the full unfiltered list
    const counts = {};
    allTabs.forEach(t => counts[t.domain] = (counts[t.domain] || 0) + 1);
    const top12 = Object.entries(counts).sort((a, b) => b[1] - a[1]).slice(0, 12);

    bar.style.display = 'flex';
    bar.innerHTML = '<span class=\"group-bar-label\">Jump:</span>' +
      top12.map(([d, c]) =>
        `<span class=\"group-chip ${activeFilter === d ? 'active' : ''}\"
               onclick=\"setFilter('${d.replace(/'/g, \"\\\\'\")}')\">${escapeHtml(d)}&nbsp;<span style=\"opacity:.5\">${c}</span></span>`
      ).join('');
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /** Switch between Window and Domain grouping modes. */
  function setGroupMode(mode) {
    groupMode = mode;
    activeFilter = null;
    document.getElementById('btn-window').classList.toggle('active', mode === 'window');
    document.getElementById('btn-domain').classList.toggle('active', mode === 'domain');
    // .showing-domain on #container enables the domain pill in each tab row
    document.getElementById('container').className = mode === 'domain' ? 'showing-domain' : '';
    renderGroupBar();
    render();
  }

  /** Toggle (or clear) a domain chip filter. Clicking the active chip clears it. */
  function setFilter(domain) {
    activeFilter = activeFilter === domain ? null : domain;
    renderGroupBar();
    render();
  }

  /** Live-search handler — fires on every keystroke. */
  function filterTabs() {
    searchQuery = document.getElementById('search').value;
    render();
  }

  /** Toggle collapse state of a single section. */
  function toggleSection(gi) {
    document.getElementById('sec-' + gi).classList.toggle('collapsed');
  }

  /** Expand or collapse every section at once. */
  function toggleAll(expand) {
    document.querySelectorAll('.section').forEach(s => s.classList.toggle('collapsed', !expand));
  }

  // ── Clipboard helpers ─────────────────────────────────────────────────────

  /** Show a brief confirmation toast then auto-hide after 2 s. */
  function showToast(msg) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.classList.add('show');
    setTimeout(() => el.classList.remove('show'), 2000);
  }

  /** Copy every URL from one section group to the clipboard. */
  function copyGroupUrls(gi) {
    const urls = window._groups[gi].tabs.map(t => t.url).join('\\n');
    navigator.clipboard.writeText(urls).then(() => showToast('URLs copied!'));
  }

  /** Copy all URLs across every tab to the clipboard. */
  function copyAllUrls() {
    const urls = allTabs.map(t => t.url).join('\\n');
    navigator.clipboard.writeText(urls).then(() => showToast(`All ${allTabs.length} URLs copied!`));
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  renderStats();
  render();
</script>

</body>
</html>"


-- =============================================================================
--  STEP 3 — Save HTML to Desktop and open it in the default browser
-- =============================================================================

set desktopPath to (path to desktop as text) & "TabCollector.html"

-- Write (or overwrite) the output file
set fileRef to open for access file desktopPath with write permission
set eof of fileRef to 0   -- clear any previous content
write htmlContent to fileRef
close access fileRef

-- Open in default browser
do shell script "open " & quoted form of POSIX path of desktopPath

display notification "Saved TabCollector.html to Desktop — opening now." with title "Tab Collector ✓"


-- =============================================================================
--  HELPER HANDLERS
-- =============================================================================

-- replaceText
--   AppleScript has no native string replace, so we use text item delimiters
--   as a find-and-replace mechanism.
--
--   Parameters:
--     theText    — the source string to search within
--     findStr    — the substring to find
--     replaceStr — the replacement string
--   Returns: a new string with all occurrences of findStr replaced
on replaceText(theText, findStr, replaceStr)
	set AppleScript's text item delimiters to findStr
	set theItems to text items of theText
	set AppleScript's text item delimiters to replaceStr
	set theText to theItems as string
	set AppleScript's text item delimiters to ""
	return theText
end replaceText
