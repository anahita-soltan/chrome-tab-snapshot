# chrome-tab-snapshot
A macOS AppleScript that snapshots all your open Chrome tabs and generates a beautiful, interactive HTML viewer — so you can browse, search, and organize them without losing anything.

# Tab Collector

A macOS AppleScript that snapshots all your open Chrome tabs and generates a beautiful, interactive HTML viewer — so you can browse, search, and organize them without losing anything.

![Tab Collector](<img width="2964" height="1840" alt="image" src="https://github.com/user-attachments/assets/514ead64-8e65-46f0-a5d6-592eae4ab12a" />)
<img width="1482" height="920" alt="Tab Collector screenshot" src="https://github.com/user-attachments/assets/514ead64-8e65-46f0-a5d6-592eafe4ab12a">
![Tab Collector screenshot](https://github.com/user-attachments/assets/514ead64-8e65-46f0-a5d6-592eafe4ab12a)

## Features

- **Two grouping modes** — view tabs organized by Chrome Window, or collapsed by Domain
- **Live search** — filters across all titles and URLs instantly as you type
- **Domain jump bar** — in Domain mode, the top 12 domains appear as one-click filter chips
- **Open links directly** — every tab has an `Open ↗` button that launches it in a new tab
- **Copy URLs** — copy all URLs in a group, or every URL at once (great for sharing or saving sessions)
- **Expand / Collapse** — fold sections you don't need; a hidden-tab count keeps you oriented
- **Stats at a glance** — total windows, tabs, and unique domains shown in the header
- **Self-contained output** — the HTML file has no runtime dependencies beyond Google Fonts

## Requirements

- macOS (tested on Ventura / Sonoma)
- Google Chrome (must be open with at least one window)
- Script Editor (built into macOS)

## Usage

1. Open **Script Editor** — press `⌘Space` and type "Script Editor"
2. Open `chrome_tab_collector.applescript` (File → Open) or paste the contents into a new document
3. Click **Run ▶**
4. If prompted, click **OK** to allow Script Editor to control Chrome
5. `TabCollector.html` is saved to your Desktop and opens automatically in your default browser

> Re-run the script any time to refresh the snapshot. Each run overwrites the previous `TabCollector.html`.

## How It Works

The script has three stages:

**Stage 1 — Data collection**
AppleScript talks to Chrome via its scripting dictionary and walks every window and tab, building a JSON array of `{ title, url }` objects.

**Stage 2 — HTML generation**
The JSON data is embedded directly into a self-contained HTML file. The viewer is written in vanilla JavaScript with no frameworks — just a `<style>` block and a `<script>` block. Favicons are fetched lazily from Google's favicon service.

**Stage 3 — Output**
The file is written to `~/Desktop/TabCollector.html` and opened with `open`, which hands it to your default browser.

## Customization

| What to change | Where |
|---|---|
| Output file location | `set desktopPath to ...` near the bottom of the script |
| Color scheme | CSS `:root` variables at the top of the `<style>` block |
| Number of domain chips shown | `.slice(0, 12)` inside `renderGroupBar()` |
| Font choices | The Google Fonts `<link>` tag and `font-family` declarations |

## Limitations

- **Chrome only** — Safari and Firefox use different scripting interfaces; adding them is a planned improvement
- **Requires GUI access** — the script must be run from Script Editor or an app with Automation permission; it cannot run headlessly from Terminal as-is
- **Favicons need network** — the favicon images are fetched from Google's CDN on first open; they won't appear offline

