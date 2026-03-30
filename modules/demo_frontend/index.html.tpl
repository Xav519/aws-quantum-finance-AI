<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Optimize Cyber Incident Response</title>
  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600;700&family=Syne:wght@400;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg:        #0b1220;
      --surface:   #111827;
      --surface2:  #0b1220;
      --surface3:  #374151;
      --border:    #1f2937;
      --border2:   #374151;
      --text:      #f9fafb;
      --muted:     #9ca3af;
      --muted2:    #6b7280;
      --optimize: #2ea94a;
      --generateBtn:  #0b1220;
      --classical: #10b981;
      --classical2: #065f46;
      --quantum:   #8b5cf6;
      --quantum2:  #4c1d95;
      --accent:    #3b82f6;
      --accent2:   #1e40af;
      --danger:    #ef4444;
      --danger2:   #7f1d1d;
      --gold:      #f6c343;
      --gold2:     #4a3500;
      --glow-c:    rgba(0, 214, 143, 0.12);
      --glow-q:    rgba(168, 85, 247, 0.12);
      --glow-a:    rgba(56, 178, 248, 0.08);
    }

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      background: var(--bg);
      color: var(--text);
      font-family: 'Syne', sans-serif;
      min-height: 100vh;
      overflow-x: hidden;
    }

    /* ── Scanline overlay ── */
    body::before {
      content: '';
      position: fixed;
      inset: 0;
      background: repeating-linear-gradient(
        0deg,
        transparent,
        transparent 2px,
        rgba(0,0,0,0.08) 2px,
        rgba(0,0,0,0.08) 4px
      );
      pointer-events: none;
      z-index: 1000;
    }

    /* ── Grid lines background ── */
    body::after {
      content: '';
      position: fixed;
      inset: 0;
      background-image:
        linear-gradient(var(--border) 1px, transparent 1px),
        linear-gradient(90deg, var(--border) 1px, transparent 1px);
      background-size: 48px 48px;
      opacity: 0.25;
      pointer-events: none;
      z-index: 0;
    }

    .page-wrapper {
      position: relative;
      z-index: 1;
      max-width: 1100px;
      margin: 0 auto;
      padding: 2rem 2rem 4rem;
    }

    /* ── Header ── */
    header {
      margin-bottom: 2.5rem;
      padding-bottom: 2rem;
      border-bottom: 1px solid var(--border2);
      position: relative;
    }

    .header-eyebrow {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      margin-bottom: 0.75rem;
    }

    .eyebrow-tag {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.65rem;
      letter-spacing: 0.15em;
      text-transform: uppercase;
      color: var(--muted);
      padding: 0.2rem 0.7rem;
      border: 1px solid var(--border2);
      border-radius: 3px;
    }

    .live-badge {
      display: inline-flex;
      align-items: center;
      gap: 0.45rem;
      background: rgba(0, 214, 143, 0.06);
      border: 1px solid rgba(0, 214, 143, 0.3);
      color: var(--classical);
      padding: 0.2rem 0.75rem;
      border-radius: 3px;
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.65rem;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      font-weight: 600;
    }

    .live-dot {
      width: 6px; height: 6px;
      background: var(--classical);
      border-radius: 50%;
      animation: pulse 1.5s ease-in-out infinite;
      box-shadow: 0 0 6px var(--classical);
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; box-shadow: 0 0 6px var(--classical); }
      50%       { opacity: 0.4; box-shadow: 0 0 2px var(--classical); }
    }

    header h1 {
      font-size: 2.4rem;
      font-weight: 800;
      letter-spacing: -0.03em;
      line-height: 1.1;
      margin-bottom: 0.5rem;
    }

    header h1 .soc  {
      color: var(--optimize);
    }
    header h1 .opt  {
      color: var(--quantum);
    }

    .header-sub {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.72rem;
      color: var(--muted);
      letter-spacing: 0.05em;
      margin-top: 0.4rem;
    }

    /* ── Explainer ── */
    .explainer {
      background: var(--surface);
      border: 1px solid var(--border2);
      border-radius: 6px;
      padding: 0;
      margin-bottom: 2rem;
      font-size: 0.95rem;
      line-height: 1.6;
      color: var(--muted);
      font-weight: 400;
      overflow: hidden;
    }

    .explainer-block {
      padding: 1.1rem 1.5rem;
      border-left: 3px solid transparent;
    }

    .explainer-block.problem {
      border-left-color: var(--danger);
      background: rgba(255, 64, 96, 0.04);
    }

    .explainer-block.calculus {
      border-left-color: var(--accent);
      background: rgba(56, 178, 248, 0.04);
      border-top: 1px solid var(--border);
      border-bottom: 1px solid var(--border);
    }

    .explainer-block.goal {
      border-left-color: var(--classical);
      background: rgba(0, 214, 143, 0.04);
    }

    .explainer-block strong.label {
      font-weight: 700;
      font-size: 0.8rem;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      display: block;
      margin-bottom: 0.4rem;
    }

    .explainer-block.calculus strong.label {
      display: inline;
      margin-bottom: 0;
      margin-right: 0.5rem;
    }

    .explainer-block.problem strong.label { color: var(--danger); }
    .explainer-block.calculus strong.label { color: var(--accent); }
    .explainer-block.goal strong.label { color: var(--classical); }

    .explainer-block strong.kw { color: var(--text); font-weight: 700; }

    .formula-stage {
      display: inline;
    }

    .formula {
      display: inline-block;
      background: var(--surface2);
      border: 1px solid var(--border2);
      border-radius: 6px;
      padding: 0.55rem 1.5rem;
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.88rem;
      color: var(--gold);
      letter-spacing: 0.04em;
      box-shadow: 0 4px 20px rgba(246, 195, 67, 0.1), 0 0 0 1px rgba(246, 195, 67, 0.08);
    }

    /* ── Config row ── */
    .config-row {
      display: flex;
      align-items: flex-end;
      gap: 1.25rem;
      flex-wrap: wrap;
      margin-bottom: 1.5rem;
    }

    .control {
      display: flex;
      flex-direction: column;
      gap: 0.4rem;
    }

    .control label {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.65rem;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      color: var(--muted);
    }

    select {
      background: var(--surface);
      border: 1px solid var(--border2);
      color: var(--text);
      border-radius: 5px;
      padding: 0.6rem 1rem;
      font-size: 0.85rem;
      font-family: 'Syne', sans-serif;
      font-weight: 600;
      cursor: pointer;
      min-width: 200px;
      transition: border-color 0.15s, box-shadow 0.15s;
    }

    select:focus {
      outline: none;
      border-color: var(--accent);
      box-shadow: 0 0 0 3px rgba(56, 178, 248, 0.1);
    }

    select option { background: var(--surface2); }

    /* ── Mode badge ── */
    .mode-badge {
      display: inline-flex;
      align-items: center;
      gap: 0.6rem;
      padding: 0.55rem 1.1rem;
      border-radius: 5px;
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.72rem;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      margin-left: auto;
      transition: all 0.25s;
    }

    .mode-badge.classical {
      background: rgba(0, 214, 143, 0.07);
      color: var(--classical);
      border: 1px solid rgba(0, 214, 143, 0.3);
    }

    .mode-badge.quantum {
      background: rgba(168, 85, 247, 0.08);
      color: var(--quantum);
      border: 1px solid rgba(168, 85, 247, 0.3);
    }

    .mode-badge .dot {
      width: 7px; height: 7px;
      border-radius: 50%;
      background: currentColor;
      box-shadow: 0 0 6px currentColor;
    }

    /* ── Info bar ── */
    .info-bar {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.78rem;
      color: var(--muted);
      padding: 0.65rem 1rem;
      background: var(--surface);
      border-radius: 5px;
      margin-bottom: 1.5rem;
      border-left: 3px solid var(--accent);
      letter-spacing: 0.03em;
      display: flex;
      align-items: center;
      gap: 0.5rem;
      flex-wrap: wrap;
    }

    .info-bar.quantum-mode { border-left-color: var(--quantum); }
    .info-bar span { color: var(--accent); font-weight: 700; }
    .info-bar.quantum-mode span { color: var(--quantum); }

    .info-sep {
      color: var(--border2);
      margin: 0 0.2rem;
    }

    /* ── Label chips ── */
    .chips-section {
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
      margin-bottom: 1.5rem;
    }

    .label-row {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      flex-wrap: wrap;
    }

    .chips-label {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.63rem;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      color: var(--muted2);
      width: 55px;
      flex-shrink: 0;
    }

    .label-chip {
      background: var(--surface2);
      border: 1px solid var(--border2);
      border-radius: 4px;
      padding: 0.25rem 0.65rem;
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.68rem;
      color: var(--muted);
      transition: all 0.15s;
    }

    .label-chip.analyst {
      border-left: 2px solid var(--accent);
      color: rgba(56, 178, 248, 0.8);
    }

    .label-chip.alert {
      border-left: 2px solid var(--danger);
      color: rgba(255, 64, 96, 0.8);
    }

    /* ── Table wrapper ── */
    .table-wrapper {
      background: var(--surface);
      border-radius: 8px;
      padding: 1.5rem;
      margin-bottom: 1.5rem;
      overflow-x: auto;
      border: 1px solid var(--border2);
      position: relative;
    }

    .table-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 1.1rem;
      flex-wrap: wrap;
      gap: 0.5rem;
    }

    .table-title {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.65rem;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--muted);
    }

    .total-display {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.75rem;
      color: var(--gold);
      font-weight: 600;
    }

    table { border-collapse: collapse; width: 100%; }

    th {
      background: var(--surface2);
      color: var(--muted);
      padding: 8px 12px;
      border: 1px solid var(--border);
      font-family: 'IBM Plex Mono', monospace;
      font-weight: 600;
      font-size: 0.66rem;
      letter-spacing: 0.04em;
      white-space: nowrap;
      text-transform: uppercase;
    }

    th.col-header {
      color: var(--danger);
      background: rgba(255, 64, 96, 0.05);
      font-size: 0.66rem;
    }

    td { border: 1px solid var(--border); padding: 2px; }

    td.row-header {
      background: var(--surface2);
      color: var(--accent);
      font-family: 'IBM Plex Mono', monospace;
      font-weight: 600;
      padding: 8px 12px;
      font-size: 0.66rem;
      letter-spacing: 0.03em;
      white-space: nowrap;
    }

    td input {
      width: 90px;
      height: 42px;
      text-align: center;
      background: transparent;
      border: none;
      color: var(--gold);
      font-size: 0.85rem;
      font-weight: 700;
      font-family: 'IBM Plex Mono', monospace;
      border-radius: 3px;
      transition: background 0.15s;
      letter-spacing: 0.02em;
    }

    td input:focus {
      outline: none;
      background: rgba(246, 195, 67, 0.06);
    }

    td input::placeholder {
      color: var(--border2);
      font-size: 0.75rem;
    }

    td:has(input:focus) {
      background: rgba(246, 195, 67, 0.04);
    }

    /* ── Actions ── */
    .actions {
      display: flex;
      gap: 0.75rem;
      flex-wrap: wrap;
      margin-bottom: 1.75rem;
      align-items: center;
    }

    button {
      padding: 0.65rem 1.35rem;
      border: 1px solid transparent;
      border-radius: 5px;
      font-size: 0.82rem;
      font-weight: 700;
      font-family: 'Syne', sans-serif;
      letter-spacing: 0.03em;
      cursor: pointer;
      transition: all 0.15s;
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
    }

    button:hover:not(:disabled) {
      transform: translateY(-1px);
      filter: brightness(1.1);
    }

    button:active:not(:disabled) { transform: translateY(0); }
    button:disabled { opacity: 0.35; cursor: not-allowed; }

    #btn-generate {
      background: var(--generateBtn);
      color: var(--accent);
      border-color: rgba(95, 95, 95, 0.57);
    }

    #btn-generate:hover:not(:disabled) {
      box-shadow: 0 0 16px rgba(56, 178, 248, 0.15);
    }

    #btn-clear {
      background: var(--surface);
      color: var(--muted);
      border-color: var(--border2);
    }

    #btn-submit {
      margin-left: auto;
      padding: 0.7rem 1.75rem;
      font-size: 0.88rem;
      letter-spacing: 0.05em;
    }

    #btn-submit.classical {
      background: rgba(0, 214, 143, 0.1);
      color: var(--classical);
      border-color: rgba(0, 214, 143, 0.35);
    }

    #btn-submit.classical:hover:not(:disabled) {
      background: rgba(0, 214, 143, 0.15);
      box-shadow: 0 0 24px rgba(0, 214, 143, 0.15);
    }

    #btn-submit.quantum {
      background: rgba(168, 85, 247, 0.1);
      color: var(--quantum);
      border-color: rgba(168, 85, 247, 0.35);
    }

    #btn-submit.quantum:hover:not(:disabled) {
      background: rgba(168, 85, 247, 0.15);
      box-shadow: 0 0 24px rgba(168, 85, 247, 0.15);
    }

    /* ── Quantum status ── */
    #quantum-status {
      display: none;
      background: rgba(168, 85, 247, 0.05);
      border: 1px solid rgba(168, 85, 247, 0.25);
      border-radius: 6px;
      padding: 1.1rem 1.35rem;
      margin-bottom: 1.75rem;
      font-family: 'IBM Plex Mono', monospace;
      color: #c4b5fd;
    }

    #quantum-status.show {
      display: flex;
      align-items: center;
      gap: 1rem;
    }

    #quantum-status .qs-details { flex: 1; }

    #quantum-status .qs-title {
      font-size: 0.82rem;
      font-weight: 700;
      margin-bottom: 0.3rem;
      color: var(--quantum);
    }

    #quantum-status .qs-sub {
      font-size: 0.7rem;
      color: rgba(167, 139, 250, 0.65);
      letter-spacing: 0.03em;
    }

    /* ── Spinner ── */
    .spinner {
      width: 18px; height: 18px; flex-shrink: 0;
      border: 2px solid rgba(168, 85, 247, 0.2);
      border-top-color: var(--quantum);
      border-radius: 50%;
      animation: spin 0.7s linear infinite;
    }

    @keyframes spin { to { transform: rotate(360deg); } }

    /* ── Result panel ── */
    #result-panel {
      background: var(--surface);
      border-radius: 8px;
      padding: 1.75rem;
      display: none;
      border: 1px solid var(--border2);
      animation: fadeIn 0.3s ease;
    }

    #result-panel.show { display: block; }

    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(8px); }
      to   { opacity: 1; transform: translateY(0); }
    }

    .result-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 1.25rem;
      flex-wrap: wrap;
      gap: 0.5rem;
      padding-bottom: 1rem;
      border-bottom: 1px solid var(--border);
    }

    .result-header h2 {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.75rem;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--muted);
    }

    .result-cost {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 1.6rem;
      font-weight: 700;
      color: var(--gold);
      margin-bottom: 1.25rem;
      letter-spacing: -0.02em;
      text-shadow: 0 0 30px rgba(246, 195, 67, 0.25);
    }

    .result-cost .cost-label {
      font-size: 0.7rem;
      color: var(--muted);
      display: block;
      margin-bottom: 0.2rem;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      font-weight: 600;
    }

    .result-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(230px, 1fr));
      gap: 0.6rem;
      margin-bottom: 1.5rem;
    }

    .pair-card {
      background: var(--surface2);
      border-radius: 6px;
      padding: 0.85rem 1rem;
      border-left: 2px solid transparent;
      font-family: 'IBM Plex Mono', monospace;
      transition: transform 0.15s;
    }

    .pair-card:hover { transform: translateX(3px); }

    .pair-card.classical { border-left-color: var(--classical); }
    .pair-card.quantum   { border-left-color: var(--quantum); }

    .pair-card .pair-names {
      font-weight: 700;
      margin-bottom: 0.3rem;
      font-size: 0.75rem;
      color: var(--text);
      letter-spacing: 0.02em;
    }

    .pair-card .pair-arrow {
      color: var(--muted2);
      margin: 0 0.25rem;
    }

    .pair-card .pair-cost {
      color: var(--gold);
      font-size: 0.72rem;
      opacity: 0.8;
    }

    .narrative {
      border-top: 1px solid var(--border);
      padding-top: 1.25rem;
      margin-top: 0.25rem;
      color: var(--muted);
      font-size: 0.83rem;
      line-height: 1.8;
      font-style: italic;
    }

    .error-box {
      background: rgba(255, 64, 96, 0.06);
      border: 1px solid rgba(255, 64, 96, 0.3);
      color: #fca5a5;
      border-radius: 6px;
      padding: 1rem 1.25rem;
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.8rem;
    }

    /* ── Divider ── */
    .section-divider {
      height: 1px;
      background: linear-gradient(90deg, var(--border2), transparent);
      margin: 1.75rem 0;
    }

    @media (max-width: 600px) {
      .page-wrapper { padding: 1rem 1rem 3rem; }
      header h1 { font-size: 1.6rem; }
      .mode-badge { margin-left: 0; }
      #btn-submit { margin-left: 0; }
      .result-cost { font-size: 1.25rem; }
    }
  </style>
</head>
<body>
<div class="page-wrapper">

<!-- ── Header ── -->
<header>
  <h1>
    <span class="soc">Optimize</span>
    Cyber Incident
    <span class="opt">Response</span>
  </h1>
  <p class="header-sub">
    Minimize costs with optimal analyst assignments &nbsp;·&nbsp; Xavier Dupuis
  </p>
</header>

<!-- ── Explainer ── -->
<div class="explainer">
  <div class="explainer-block problem">
    <strong class="label">The Problem</strong>
    When multiple cyber threats happen at the same time, choosing who handles what is hard and mistakes <strong>cost money</strong>.
  </div>
  <div class="explainer-block calculus">
    <strong class="label">The Solution</strong>
    <br>
    This system calculates the best assignment of analysts to threats to <strong>minimize</strong> total financial loss.
  </div>
  <div class="explainer-block goal">
    <strong class="label">How</strong>
    It compares all possible combinations using <strong>classical</strong> or <strong>quantum</strong> algorithms.
  </div>
</div>

<!-- ── Config ── -->
<div class="config-row">
  <div class="control">
    <label for="size-select">Team / Threat Size</label>
    <select id="size-select" onchange="onSizeChange()">
      <option value="2">2 Analysts · 2 Threats</option>
      <option value="3">3 Analysts · 3 Threats</option>
      <option value="4" selected>4 Analysts · 4 Threats</option>
      <option value="5">5 Analysts · 5 Threats</option>
    </select>
  </div>
  <div id="mode-badge" class="mode-badge classical">
    <span id="mode-label">Classical Brute-Force</span>
  </div>
</div>

<!-- ── Info bar ── -->
<div id="info-bar" class="info-bar">Loading…</div>

<!-- ── Chips ── -->
<div class="chips-section">
  <div id="analyst-chips" class="label-row"></div>
  <div id="alert-chips"   class="label-row"></div>
</div>

<!-- ── Table ── -->
<div class="table-wrapper">
  <div class="table-header">
    <span class="table-title">💰 Breach Impact Cost Matrix (USD)</span>
    <div class="total-display" id="live-total"></div>
  </div>
  <table id="cost-table"></table>
</div>

<!-- ── Actions ── -->
<div class="actions">
  <button id="btn-generate" onclick="generateValues()">🎲 Generate Random Values</button>
  <button id="btn-clear"    onclick="clearTable()">✕ Clear</button>
  <button id="btn-submit"   class="classical" onclick="submitJob()">▶ Find Optimal Assignment</button>
</div>

<!-- ── Quantum status ── -->
<div id="quantum-status">
  <div class="spinner"></div>
  <div class="qs-details">
    <div class="qs-title">QAOA Circuit Running on Amazon Braket SV1…</div>
    <div class="qs-sub" id="qs-info"></div>
  </div>
</div>

<!-- ── Result ── -->
<div id="result-panel"></div>

</div><!-- /page-wrapper -->

<script>
// ── Config ────────────────────────────────────────────────────────────────────
const API_URL   = "https://8gg49mhree.execute-api.us-east-1.amazonaws.com/";
const THRESHOLD = 4;

const ANALYST_NAMES = {
  2: ["Sarah (Network)", "Marc (Phishing)"],
  3: ["Sarah (Network)", "Marc (Phishing)", "David (Forensics)"],
  4: ["Sarah (Network)", "Marc (Phishing)", "David (Forensics)", "Lisa (Malware)"],
  5: ["Sarah (Network)", "Marc (Phishing)", "David (Forensics)", "Lisa (Malware)", "Chen (Cloud)"],
};
const ALERT_NAMES = {
  2: ["Ransomware", "Data Exfiltration"],
  3: ["Ransomware", "Data Exfiltration", "Phishing Campaign"],
  4: ["Ransomware", "Data Exfiltration", "Phishing Campaign", "SQL Injection"],
  5: ["Ransomware", "Data Exfiltration", "Phishing Campaign", "SQL Injection", "DDoS Attack"],
};

let pollInterval = null;

function getN() { return parseInt(document.getElementById("size-select").value); }

function factorial(n) {
  let r = 1n;
  for (let i = 2n; i <= BigInt(n); i++) r *= i;
  return r;
}

function formatUSD(val) {
  return "$" + Number(val).toLocaleString("en-US");
}

function randCost() {
  return Math.round((Math.random() * 110 + 10)) * 1000;
}

function onSizeChange() {
  const n = getN();
  buildTable(n);
  updateModeBadge(n);
  updateChips(n);
  resetResult();
}

function updateModeBadge(n) {
  const badge = document.getElementById("mode-badge");
  const label = document.getElementById("mode-label");
  const info  = document.getElementById("info-bar");
  const btn   = document.getElementById("btn-submit");
  const fact  = factorial(n).toLocaleString();

  if (n <= THRESHOLD) {
    badge.className   = "mode-badge classical";
    label.textContent = "Classical Brute-Force";
    btn.className     = "classical";
    info.className    = "info-bar";
    info.innerHTML    = `N = <span>$${n}</span> <span class="info-sep">·</span> Evaluates <span>$${fact}</span> combinations <span class="info-sep">·</span> Exact global optimum <span class="info-sep">·</span> Synchronous result`;
  } else {
    badge.className   = "mode-badge quantum";
    label.textContent = "Quantum QAOA";
    btn.className     = "quantum";
    info.className    = "info-bar quantum-mode";
    info.innerHTML    = `N = <span>$${n}</span> <span class="info-sep">·</span> <span>$${fact}</span> combinations <span class="info-sep">·</span> QAOA on Amazon Braket SV1 <span class="info-sep">·</span> <span>$${n*n} qubits</span> <span class="info-sep">·</span> 1,000 shots <span class="info-sep">·</span> Async result`;
  }
}

function updateChips(n) {
  const analysts = ANALYST_NAMES[n];
  const alerts   = ALERT_NAMES[n];
  document.getElementById("analyst-chips").innerHTML =
    '<span class="chips-label">Analysts</span>' +
    analysts.map(a => `<span class="label-chip analyst">$${a}</span>`).join("");
  document.getElementById("alert-chips").innerHTML =
    '<span class="chips-label">Threats</span>' +
    alerts.map(a => `<span class="label-chip alert">⚠ $${a}</span>`).join("");
}

function buildTable(n) {
  const analysts = ANALYST_NAMES[n];
  const alerts   = ALERT_NAMES[n];
  const t        = document.getElementById("cost-table");
  let html = "<tr><th></th>";
  alerts.forEach(a => {
    html += `<th class="col-header" title="$${a}">⚠ $${a}</th>`;
  });
  html += "</tr>";
  analysts.forEach((analyst, i) => {
    html += `<tr><td class="row-header">$${analyst}</td>`;
    alerts.forEach((_, j) => {
      html += `<td><input
        type="text"
        id="c$${i}_$${j}"
        placeholder="—"
        oninput="onCellInput(this, $${i}, $${j})"
        onkeypress="return allowCostKey(event)"
        autocomplete="off"
      /></td>`;
    });
    html += "</tr>";
  });
  t.innerHTML = html;
  updateLiveTotal();
}

function allowCostKey(e) {
  return (e.key >= '0' && e.key <= '9') || e.key === 'Backspace';
}

function onCellInput(el, i, j) {
  el.value = el.value.replace(/\D/g, "").slice(0, 6);
  updateLiveTotal();
}

function generateValues() {
  const n = getN();
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      const el = document.getElementById(`c$${i}_$${j}`);
      if (!el.value || el.value === "") el.value = randCost();
    }
  }
  updateLiveTotal();
}

function clearTable() {
  const n = getN();
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      document.getElementById(`c$${i}_$${j}`).value = "";
    }
  }
  updateLiveTotal();
  resetResult();
}

function updateLiveTotal() {
  const n   = getN();
  let   sum = 0;
  let   all = true;
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      const v = parseInt(document.getElementById(`c$${i}_$${j}`).value);
      if (!isNaN(v)) sum += v;
      else all = false;
    }
  }
  const el = document.getElementById("live-total");
  el.textContent = "";
}

function readMatrix() {
  const n = getN();
  const matrix = [];
  for (let i = 0; i < n; i++) {
    const row = [];
    for (let j = 0; j < n; j++) {
      const v = parseInt(document.getElementById(`c$${i}_$${j}`).value);
      if (isNaN(v) || v < 0) return null;
      row.push(v);
    }
    matrix.push(row);
  }
  return matrix;
}

async function submitJob() {
  const n       = getN();
  const matrix  = readMatrix();
  if (!matrix) {
    showError("All cells must be filled before running the optimizer. Use Generate Random Values.");
    return;
  }
  const analysts = ANALYST_NAMES[n];
  const alerts   = ALERT_NAMES[n];
  const payload  = { analysts, alerts, cost_matrix: matrix };
  setSubmitting(true);
  resetResult();
  try {
    const resp = await fetch(`$${API_URL}/optimize`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify(payload),
    });
    const data = await resp.json();
    if (resp.status === 202 && data.status === "PENDING") {
      showQuantumStatus(data.job_id, n, data.qubits, data.shots);
      startPolling(data.job_id, n);
    } else if (resp.ok) {
      setSubmitting(false);
      showResult(data, n);
    } else {
      setSubmitting(false);
      showError(data.error || "Unexpected error from optimizer.");
    }
  } catch (e) {
    setSubmitting(false);
    showError(`Network error: $${e.message}`);
  }
}

function startPolling(jobId, n) {
  clearInterval(pollInterval);
  pollInterval = setInterval(async () => {
    try {
      const resp = await fetch(`$${API_URL}/jobs/$${jobId}`);
      const data = await resp.json();
      if (data.status === "COMPLETE") {
        clearInterval(pollInterval);
        hideQuantumStatus();
        setSubmitting(false);
        showResult(data, n);
      } else if (data.status && data.status.startsWith("FAIL")) {
        clearInterval(pollInterval);
        hideQuantumStatus();
        setSubmitting(false);
        showError(`Quantum job failed: $${data.status}`);
      }
    } catch (_) {}
  }, 4000);
}

function showQuantumStatus(jobId, n, qubits, shots) {
  const qs = document.getElementById("quantum-status");
  qs.className = "show";
  document.getElementById("qs-info").textContent =
    `Job: $${jobId} · $${qubits} qubits · $${shots} shots · Device: Amazon Braket SV1`;
}

function hideQuantumStatus() {
  document.getElementById("quantum-status").className = "";
}

function showResult(data, n) {
  const isQuantum   = data.method === "QUANTUM";
  const pairs       = data.assignment || [];
  const total       = data.total_cost;
  const cls         = isQuantum ? "quantum" : "classical";
  const methodLabel = isQuantum
    ? "⚛ Amazon Braket SV1 — QAOA Result"
    : "✅ Brute-Force — Global Optimum Found";

  const pairsHtml = pairs.map(p => `
    <div class="pair-card $${cls}">
      <div class="pair-names">$${p.analyst}<span class="pair-arrow">→</span>⚠ $${p.alert || p.file}</div>
      <div class="pair-cost">$${formatUSD(p.cost)} breach impact</div>
    </div>
  `).join("");

  document.getElementById("result-panel").className = "show";
  document.getElementById("result-panel").innerHTML = `
    <div class="result-header">
      <h2>$${methodLabel}</h2>
    </div>
    <div class="result-cost">
      <span class="cost-label">Total Financial Exposure</span>
      $${formatUSD(total)}
    </div>
    <div class="result-grid">$${pairsHtml}</div>
    <div class="narrative">$${data.narrative || ""}</div>
  `;
}

function showError(msg) {
  const panel = document.getElementById("result-panel");
  panel.className = "show";
  panel.innerHTML = `<div class="error-box">⚠ $${msg}</div>`;
}

function setSubmitting(on) {
  ["btn-submit", "btn-generate", "btn-clear"].forEach(id => {
    document.getElementById(id).disabled = on;
  });
  const btn = document.getElementById("btn-submit");
  btn.innerHTML = on
    ? `<span class="spinner" style="border-top-color:currentColor"></span> Optimizing…`
    : "▶ Find Optimal Assignment";
}

function resetResult() {
  clearInterval(pollInterval);
  hideQuantumStatus();
  const p = document.getElementById("result-panel");
  p.className = "";
  p.innerHTML = "";
}

buildTable(4);
updateModeBadge(4);
updateChips(4);
</script>
</body>
</html>
