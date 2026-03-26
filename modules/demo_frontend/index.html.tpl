<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>SOC Quantum Optimizer — Cyber Breach Liability</title>
  <style>
    /* - CSS Variables - 
       These act as a central color palette. Changing a color here updates it everywhere.
    */
    :root {
      --bg:        #0a0f1e;
      --surface:   #111827;
      --surface2:  #0a0f1e;
      --border:    #1f2d47;
      --text:      #e2e8f0;
      --muted:     #64748b;
      --classical: #059669; /* Green theme for standard math */
      --quantum:   #7c3aed; /* Purple theme for AWS Braket */
      --accent:    #38bdf8;
      --danger:    #ef4444;
      --gold:      #f59e0b;
    }

    /* Standard reset to ensure consistent sizing across browsers */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      background: var(--bg);
      color: var(--text);
      font-family: 'Segoe UI', system-ui, sans-serif;
      padding: 2rem;
      min-height: 100vh;
    }

    /* ── Header ──────────────────────────────────────────────────────── */
    header {
      margin-bottom: 2rem;
      border-bottom: 1px solid var(--border);
      padding-bottom: 1.25rem;
    }

    .header-top {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 1rem;
    }

    header h1 {
      font-size: 1.6rem;
      font-weight: 700;
      letter-spacing: -0.3px;
      line-height: 1.2;
    }

    header h1 .soc  { color: var(--danger); }
    header h1 .opt  { color: var(--quantum); }

    header p {
      color: var(--muted);
      margin-top: 0.3rem;
      font-size: 0.85rem;
    }

    .live-badge {
      display: inline-flex;
      align-items: center;
      gap: 0.4rem;
      background: #0f1f0f;
      border: 1px solid var(--classical);
      color: #6ee7b7;
      padding: 0.3rem 0.8rem;
      border-radius: 99px;
      font-size: 0.75rem;
      font-weight: 700;
      letter-spacing: 0.5px;
      white-space: nowrap;
    }

    .live-dot {
      width: 7px; height: 7px;
      background: var(--classical);
      border-radius: 50%;
      animation: pulse 1.5s ease-in-out infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50%       { opacity: 0.3; }
    }

    /* ── Explainer box ───────────────────────────────────────────────── */
    .explainer {
      background: var(--surface);
      border: 1px solid var(--border);
      border-left: 4px solid var(--accent);
      border-radius: 10px;
      padding: 1rem 1.25rem;
      margin-bottom: 1.5rem;
      font-size: 0.85rem;
      line-height: 1.7;
      color: var(--muted);
    }

    .explainer strong { color: var(--text); }

    .explainer .formula {
      display: inline-block;
      background: var(--surface2);
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 0.2rem 0.7rem;
      font-family: monospace;
      font-size: 0.82rem;
      color: var(--gold);
      margin: 0.3rem 0;
    }

    /* ── Config row ──────────────────────────────────────────────────── */
    .config-row {
      display: flex;
      align-items: center;
      gap: 1.25rem;
      flex-wrap: wrap;
      margin-bottom: 1.25rem;
    }

    .config-row label { color: var(--muted); font-size: 0.82rem; margin-bottom: 0.3rem; display: block; }

    .control { display: flex; flex-direction: column; }

    select {
      background: var(--surface);
      border: 1px solid var(--border);
      color: var(--text);
      border-radius: 7px;
      padding: 0.5rem 0.85rem;
      font-size: 0.9rem;
      cursor: pointer;
      min-width: 130px;
    }
    select:focus { outline: 2px solid var(--accent); }

    /* ── Mode badge ──────────────────────────────────────────────────── */
    .mode-badge {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.4rem 1rem;
      border-radius: 99px;
      font-size: 0.78rem;
      font-weight: 700;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      margin-left: auto;
    }
    .mode-badge.classical { background: #052e16; color: #86efac; border: 1px solid var(--classical); }
    .mode-badge.quantum   { background: #2e1065; color: #d8b4fe; border: 1px solid var(--quantum); }
    .mode-badge .dot { width: 7px; height: 7px; border-radius: 50%; background: currentColor; }

    /* ── Info bar ────────────────────────────────────────────────────── */
    .info-bar {
      font-size: 0.8rem;
      color: var(--muted);
      padding: 0.55rem 1rem;
      background: var(--surface);
      border-radius: 7px;
      margin-bottom: 1.25rem;
      border-left: 3px solid var(--accent);
    }
    .info-bar.quantum-mode { border-left-color: var(--quantum); }
    .info-bar span { color: var(--text); font-weight: 600; }

    /* ── Table ───────────────────────────────────────────────────────── */
    .table-wrapper {
      background: var(--surface);
      border-radius: 12px;
      padding: 1.25rem;
      margin-bottom: 1.25rem;
      overflow-x: auto;
      border: 1px solid var(--border);
    }

    .table-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 0.85rem;
      flex-wrap: wrap;
      gap: 0.5rem;
    }

    .table-header h3 {
      font-size: 0.78rem;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 1px;
    }

    .table-header .total-display {
      font-size: 0.82rem;
      color: var(--gold);
      font-weight: 600;
    }

    table { border-collapse: collapse; font-size: 0.83rem; }

    th {
      background: var(--surface2);
      color: var(--muted);
      padding: 7px 10px;
      border: 1px solid var(--border);
      font-weight: 600;
      white-space: nowrap;
      font-size: 0.75rem;
      max-width: 110px;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    td { border: 1px solid var(--border); padding: 2px; }

    td input {
      width: 80px;
      height: 38px;
      text-align: center;
      background: transparent;
      border: none;
      color: var(--gold);
      font-size: 0.85rem;
      font-weight: 700;
      border-radius: 4px;
      transition: background 0.15s;
      font-family: 'Segoe UI', monospace;
    }
    td input:focus { outline: none; background: #1a2a40; }
    td input::placeholder { color: var(--border); font-size: 0.75rem; }

    td.row-header, th.col-header {
      background: var(--surface2);
      color: var(--accent);
      font-weight: 700;
      padding: 7px 10px;
      font-size: 0.75rem;
      white-space: nowrap;
    }

    /* ── Analyst/Alert name labels ───────────────────────────────────── */
    .label-row {
      display: flex;
      gap: 0.5rem;
      flex-wrap: wrap;
      margin-bottom: 0.75rem;
    }

    .label-chip {
      background: var(--surface2);
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 3px 10px;
      font-size: 0.75rem;
      color: var(--muted);
    }

    .label-chip.analyst { border-left: 3px solid var(--accent); }
    .label-chip.alert   { border-left: 3px solid var(--danger); }

    /* ── Buttons ─────────────────────────────────────────────────────── */
    .actions {
      display: flex;
      gap: 0.75rem;
      flex-wrap: wrap;
      margin-bottom: 1.5rem;
    }

    button {
      padding: 0.6rem 1.25rem;
      border: none;
      border-radius: 8px;
      font-size: 0.88rem;
      font-weight: 600;
      cursor: pointer;
      transition: opacity 0.15s, transform 0.1s;
      display: inline-flex;
      align-items: center;
      gap: 0.45rem;
    }
    button:hover:not(:disabled) { opacity: 0.85; transform: translateY(-1px); }
    button:active:not(:disabled){ transform: translateY(0); }
    button:disabled { opacity: 0.4; cursor: not-allowed; }

    #btn-generate { background: #1e3a5f; color: var(--accent); border: 1px solid var(--accent); }
    #btn-clear    { background: var(--surface); color: var(--muted); border: 1px solid var(--border); }
    #btn-submit.classical { background: var(--classical); color: white; }
    #btn-submit.quantum   { background: var(--quantum); color: white; }

    /* ── Quantum status ──────────────────────────────────────────────── */
    #quantum-status {
      display: none;
      background: #1a0a2e;
      border: 1px solid var(--quantum);
      border-radius: 10px;
      padding: 1rem 1.25rem;
      margin-bottom: 1.5rem;
      font-size: 0.85rem;
      color: #c4b5fd;
    }
    #quantum-status.show {
      display: flex;
      align-items: flex-start;
      gap: 0.85rem;
    }
    #quantum-status .qs-details { flex: 1; }
    #quantum-status .qs-title   { font-weight: 700; margin-bottom: 0.2rem; }
    #quantum-status .qs-sub     { font-size: 0.78rem; color: #a78bfa; font-family: monospace; }

    /* ── Spinner ─────────────────────────────────────────────────────── */
    .spinner {
      width: 18px; height: 18px; flex-shrink: 0;
      border: 2px solid rgba(255,255,255,0.2);
      border-top-color: currentColor;
      border-radius: 50%;
      animation: spin 0.7s linear infinite;
      margin-top: 2px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }

    /* ── Result panel ────────────────────────────────────────────────── */
    #result-panel {
      background: var(--surface);
      border-radius: 12px;
      padding: 1.5rem;
      display: none;
      border: 1px solid var(--border);
      animation: fadeIn 0.3s ease;
    }
    #result-panel.show { display: block; }
    @keyframes fadeIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; } }

    .result-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 1rem;
      flex-wrap: wrap;
      gap: 0.5rem;
    }

    .result-header h2 { font-size: 1rem; }

    .result-cost {
      font-size: 1.4rem;
      font-weight: 800;
      color: var(--gold);
      margin-bottom: 1rem;
      font-family: monospace;
    }

    .result-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 0.5rem;
      margin-bottom: 1.25rem;
    }

    .pair-card {
      background: var(--surface2);
      border-radius: 8px;
      padding: 0.65rem 0.9rem;
      border-left: 3px solid transparent;
      font-size: 0.83rem;
    }
    .pair-card.classical { border-left-color: var(--classical); }
    .pair-card.quantum   { border-left-color: var(--quantum); }

    .pair-card .pair-names {
      font-weight: 700;
      margin-bottom: 0.2rem;
      font-size: 0.82rem;
    }

    .pair-card .pair-cost {
      color: var(--gold);
      font-family: monospace;
      font-size: 0.8rem;
    }

    .narrative {
      border-top: 1px solid var(--border);
      padding-top: 1rem;
      margin-top: 0.5rem;
      color: var(--muted);
      font-size: 0.85rem;
      line-height: 1.7;
      font-style: italic;
    }

    .error-box {
      background: #2d0a0a;
      border: 1px solid var(--danger);
      color: #fca5a5;
      border-radius: 8px;
      padding: 0.85rem 1rem;
      font-size: 0.85rem;
    }

    @media (max-width: 600px) {
      body { padding: 1rem; }
      header h1 { font-size: 1.2rem; }
    }
  </style>
</head>
<body>

<!-- ── Header ──────────────────────────────────────────────────────────────── -->
<header>
  <div class="header-top">
    <div>
      <h1>
        <span class="soc">⚠ SOC</span>
        Cyber Breach Liability
        <span class="opt">Optimizer</span>
      </h1>
      <p>Security Operations Center · Analyst-to-Threat Assignment · AWS Braket SV1 + Amazon Bedrock · Xavier Dupuis</p>
    </div>
    <div class="live-badge">
      <span class="live-dot"></span>
      LIVE DEMO
    </div>
  </div>
</header>

<!-- ── Explainer ───────────────────────────────────────────────────────────── -->
<div class="explainer">
  <strong>The Problem:</strong> When multiple cyber threats hit simultaneously, every minute of unmitigated breach costs the bank money.
  Assigning the wrong analyst to the wrong threat — a greedy "local" decision — can dramatically increase total financial exposure.
  <br><br>
  <strong>The Model:</strong>
  <span class="formula">Breach Impact Cost = Hourly Financial Loss × Hours to Mitigate</span>
  <br>
  Each cell represents the total dollar cost if that specific analyst handles that specific threat.
  A Network Specialist resolves a Data Exfiltration alert in 2 hours; a Phishing Specialist takes 9 hours — the difference is hundreds of thousands of dollars.
  <br><br>
  <strong>The Goal:</strong> Find the one assignment out of N! possibilities that minimizes the bank's
  <strong>Global Financial Liability</strong> — not just a good solution, but the mathematically optimal one.
</div>

<!-- ── Config row ──────────────────────────────────────────────────────────── -->
<div class="config-row">
  <div class="control">
    <label for="size-select">Team / Threat Size</label>
    <select id="size-select" onchange="onSizeChange()">
      <option value="2">2 Analysts · 2 Threats</option>
      <option value="3">3 Analysts · 3 Threats</option>
      <option value="4" selected>4 Analysts · 4 Threats</option>
      <option value="5">5 Analysts · 5 Threats</option>
      <option value="6">6 Analysts · 6 Threats</option>
    </select>
  </div>

  <div id="mode-badge" class="mode-badge classical">
    <span class="dot"></span>
    <span id="mode-label">Classical Mode</span>
  </div>
</div>

<!-- ── Info bar ────────────────────────────────────────────────────────────── -->
<div id="info-bar" class="info-bar">
  Loading...
</div>

<!-- ── Label chips ─────────────────────────────────────────────────────────── -->
<div id="analyst-chips" class="label-row"></div>
<div id="alert-chips"   class="label-row"></div>

<!-- ── Cost matrix table ───────────────────────────────────────────────────── -->
<div class="table-wrapper">
  <div class="table-header">
    <h3>💰 Breach Impact Cost Matrix (USD)</h3>
    <div class="total-display" id="live-total"></div>
  </div>
  <table id="cost-table"></table>
</div>

<!-- ── Actions ─────────────────────────────────────────────────────────────── -->
<div class="actions">
  <button id="btn-generate" onclick="generateValues()">🎲 Generate Random Values</button>
  <button id="btn-clear"    onclick="clearTable()">✕ Clear</button>
  <button id="btn-submit"   class="classical" onclick="submitJob()">▶ Find Optimal Assignment</button>
</div>

<!-- ── Quantum status ──────────────────────────────────────────────────────── -->
<div id="quantum-status">
  <div class="spinner"></div>
  <div class="qs-details">
    <div class="qs-title">⚛ QAOA Circuit Running on Amazon Braket SV1…</div>
    <div class="qs-sub" id="qs-info"></div>
  </div>
</div>

<!-- ── Result ──────────────────────────────────────────────────────────────── -->
<div id="result-panel"></div>

<script>
// ── Config ────────────────────────────────────────────────────────────────────
// IMPORTANT: You need to replace this variable with your actual AWS API Gateway endpoint URL 
// that triggers your Orchestrator Lambda.
const API_URL   = "${api_url}";

// This is the logic gate. If the grid is 4x4 or smaller, the UI assumes it will 
// hit your Classical Brute-Force Lambda. If 5x5 or larger, it assumes Quantum.
const THRESHOLD = 4;  // N <= 4 classical, N >= 5 quantum

// ── SOC analyst and threat names ──────────────────────────────────────────────
// Hardcoded dummy data to make the UI look realistic depending on the grid size selected.
const ANALYST_NAMES = {
  2: ["Sarah (Network)", "Marc (Phishing)"],
  3: ["Sarah (Network)", "Marc (Phishing)", "David (Forensics)"],
  4: ["Sarah (Network)", "Marc (Phishing)", "David (Forensics)", "Lisa (Malware)"],
  5: ["Sarah (Network)", "Marc (Phishing)", "David (Forensics)", "Lisa (Malware)", "Chen (Cloud)"],
  6: ["Sarah (Network)", "Marc (Phishing)", "David (Forensics)", "Lisa (Malware)", "Chen (Cloud)", "Aisha (Insider)"],
};

const ALERT_NAMES = {
  2: ["Ransomware", "Data Exfiltration"],
  3: ["Ransomware", "Data Exfiltration", "Phishing Campaign"],
  4: ["Ransomware", "Data Exfiltration", "Phishing Campaign", "SQL Injection"],
  5: ["Ransomware", "Data Exfiltration", "Phishing Campaign", "SQL Injection", "DDoS Attack"],
  6: ["Ransomware", "Data Exfiltration", "Phishing Campaign", "SQL Injection", "DDoS Attack", "Insider Threat"],
};

// This variable will hold our timer for when we need to check the status of a Quantum job.
let pollInterval = null;

// ── Helpers ───────────────────────────────────────────────────────────────────
// Grabs the current grid size (N) from the dropdown menu
function getN() { return parseInt(document.getElementById("size-select").value); }

// Calculates factorials (N!) to show the user how many combinations exist.
// Uses BigInt because factorials get massive quickly and normal numbers would overflow.
function factorial(n) {
  let r = 1n;
  for (let i = 2n; i <= BigInt(n); i++) r *= i;
  return r;
}

// Formats a raw number like 10000 into $10,000
function formatUSD(val) {
  return "$" + Number(val).toLocaleString("en-US");
}

// Generates a random realistic dollar amount between $10k and $120k
function randCost() {
  // Random value between $10,000 and $120,000, rounded to nearest $1,000
  return Math.round((Math.random() * 110 + 10)) * 1000;
}

// -- Size change (UI updates)───────────────────────────────────────────────────────────────
// Triggered whenever the user changes the dropdown from 4x4 to 5x5, etc.
function onSizeChange() {
  const n = getN();
  buildTable(n);
  updateModeBadge(n);
  updateChips(n);
  resetResult();
}

// Updates the visual theme based on whether N is over the THRESHOLD (4)
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
    info.innerHTML    = `N = ${n} &nbsp;·&nbsp; Evaluates <span>${fact}</span> combinations &nbsp;·&nbsp; Exact global optimum &nbsp;·&nbsp; Synchronous result`;
  } else {
    badge.className   = "mode-badge quantum";
    label.textContent = "⚛ Quantum QAOA";
    btn.className     = "quantum";
    info.className    = "info-bar quantum-mode";
    info.innerHTML    = `N = ${n} &nbsp;·&nbsp; <span>${fact}</span> combinations &nbsp;·&nbsp; QAOA on Amazon Braket SV1 &nbsp;·&nbsp; <span>${n*n} qubits</span> · 1,000 shots &nbsp;·&nbsp; Async result`;
  }
}

function updateChips(n) {
  const analysts = ANALYST_NAMES[n];
  const alerts   = ALERT_NAMES[n];

  document.getElementById("analyst-chips").innerHTML =
    '<span style="font-size:0.75rem;color:var(--muted);margin-right:4px">Analysts:</span>' +
    analysts.map(a => `<span class="label-chip analyst">${a}</span>`).join("");

  document.getElementById("alert-chips").innerHTML =
    '<span style="font-size:0.75rem;color:var(--muted);margin-right:4px">Threats:</span>' +
    alerts.map(a => `<span class="label-chip alert">⚠ ${a}</span>`).join("");
}

// ── Build table ───────────────────────────────────────────────────────────────
// Dynamically constructs the HTML string for the rows and columns based on N.
function buildTable(n) {
  const analysts = ANALYST_NAMES[n];
  const alerts   = ALERT_NAMES[n];
  const t        = document.getElementById("cost-table");

  let html = "<tr><th></th>";
  alerts.forEach(a => {
    html += `<th class="col-header" title="${a}">⚠ ${a}</th>`;
  });
  html += "</tr>";

  analysts.forEach((analyst, i) => {
    html += `<tr><td class="row-header">${analyst}</td>`;
    alerts.forEach((_, j) => {
      html += `<td><input
        type="text"
        id="c${i}_${j}"
        placeholder="—"
        oninput="onCellInput(this, ${i}, ${j})"
        onkeypress="return allowCostKey(event)"
        autocomplete="off"
      /></td>`;
    });
    html += "</tr>";
  });

  t.innerHTML = html;
  updateLiveTotal();
}

// Prevents users from typing letters into the cost boxes
function allowCostKey(e) {
  return (e.key >= '0' && e.key <= '9') || e.key === 'Backspace';
}

// Truncates numbers if they get too long so the UI doesn't break
function onCellInput(el, i, j) {
  // Keep numeric only, max 6 digits (up to $999,000)
  el.value = el.value.replace(/\D/g, "").slice(0, 6);
  updateLiveTotal();
}

// ── Generate random values ────────────────────────────────────────────────────
// Loops through every input box and fills it with randCost() if it's currently empty
function generateValues() {
  const n = getN();
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      const el = document.getElementById(`c${i}_${j}`);
      if (!el.value || el.value === "") {
        el.value = randCost();
      }
    }
  }
  updateLiveTotal();
}

// ── Clear ─────────────────────────────────────────────────────────────────────
function clearTable() {
  const n = getN();
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      document.getElementById(`c${i}_${j}`).value = "";
    }
  }
  updateLiveTotal();
  resetResult();
}

// ── Live total ────────────────────────────────────────────────────────────────
// Calculates the sum of all currently typed values just to show some live data
function updateLiveTotal() {
  const n   = getN();
  let   sum = 0;
  let   all = true;
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      const v = parseInt(document.getElementById(`c${i}_${j}`).value);
      if (!isNaN(v)) sum += v;
      else all = false;
    }
  }
  const el = document.getElementById("live-total");
  el.textContent = all
    ? `Matrix sum: ${formatUSD(sum)}`
    : sum > 0 ? `Partial sum: ${formatUSD(sum)}` : "";
}

// ── Read matrix ───────────────────────────────────────────────────────────────
// Extracts all the values from the HTML inputs and packs them into a 2D Array
// This is exactly the "cost_matrix" format my AWS Lambda expects.
function readMatrix() {
  const n = getN();
  const matrix = [];
  for (let i = 0; i < n; i++) {
    const row = [];
    for (let j = 0; j < n; j++) {
      const v = parseInt(document.getElementById(`c${i}_${j}`).value);
      if (isNaN(v) || v < 0) return null; // Fails if any cell is empty
      row.push(v);
    }
    matrix.push(row);
  }
  return matrix;
}

// ── API Submission ────────────────────────────────────────────────────────────────────
// Triggered when you click the "Find Optimal Assignment" button
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
    const resp = await fetch(`${API_URL}/optimize`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify(payload),
    });

    const data = await resp.json();

    // The core logic divergence: 
    // If the API returns 202 (Accepted) and "PENDING", it means the job was sent to the Quantum simulator.
    if (resp.status === 202 && data.status === "PENDING") {
      showQuantumStatus(data.job_id, n, data.qubits, data.shots);
      startPolling(data.job_id, n); // Starts checking the API every few seconds for the result

    // If the API returns instantly (e.g., 200 OK), it was the Classical brute-force.
    } else if (resp.ok) {
      setSubmitting(false);
      showResult(data, n);
    } else {
      setSubmitting(false);
      showError(data.error || "Unexpected error from optimizer.");
    }
  } catch (e) {
    setSubmitting(false);
    showError(`Network error: ${e.message}`);
  }
}

// ── Asynchronous Polling (For Quantum Jobs) ───────────────────────────────────
// Because Amazon Braket takes time to provision and run the quantum circuit,
// the frontend needs to repeatedly ask the backend: "Are you done yet?"
function startPolling(jobId, n) {
  clearInterval(pollInterval); // Clear any old timers just in case

  // setInterval runs the code inside it repeatedly (every 4000ms / 4 seconds)
  pollInterval = setInterval(async () => {
    try {
      // Call the API GET endpoint to check job status
      const resp = await fetch(`${API_URL}/jobs/${jobId}`);
      const data = await resp.json();

      // If the job is done running on Braket and Claude generated the summary...
      if (data.status === "COMPLETE") {
        clearInterval(pollInterval);
        hideQuantumStatus();
        setSubmitting(false);
        showResult(data, n);

      // If the Braket task failed for some reason...
      } else if (data.status && data.status.startsWith("FAIL")) {
        clearInterval(pollInterval);
        hideQuantumStatus();
        setSubmitting(false);
        showError(`Quantum job failed: ${data.status}`);
      }
      // If it's still "PENDING", do nothing. The interval will just run again in 4 seconds.
    } catch (_) { /* keep polling on transient errors */ }
  }, 4000);
}

// UI helper to show the purple "Braket is running" banner
function showQuantumStatus(jobId, n, qubits, shots) {
  const qs = document.getElementById("quantum-status");
  qs.className = "show";
  document.getElementById("qs-info").textContent =
    `Job: ${jobId} · ${qubits} qubits · ${shots} shots · Device: Amazon Braket SV1`;
}

function hideQuantumStatus() {
  document.getElementById("quantum-status").className = "";
}

// ── Show result ───────────────────────────────────────────────────────────────
// Takes the final JSON from the API (whether Classical or Quantum) and builds the UI cards.
function showResult(data, n) {
  const isQuantum = data.method === "QUANTUM";
  const pairs     = data.assignment || [];
  const total     = data.total_cost;
  const cls       = isQuantum ? "quantum" : "classical";

  const methodLabel = isQuantum
    ? "⚛ Amazon Braket SV1 — QAOA Result"
    : "✅ Brute-Force — Global Optimum Found";

  // Loops through the assigned pairs and creates HTML cards for each
  const pairsHtml = pairs.map(p => `
    <div class="pair-card ${cls}">
      <div class="pair-names">${p.analyst} → ⚠ ${p.alert || p.file}</div>
      <div class="pair-cost">${formatUSD(p.cost)} breach impact</div>
    </div>
  `).join("");

  // Injects the cards, the total cost, and the Bedrock narrative into the DOM
  document.getElementById("result-panel").className = "show";
  document.getElementById("result-panel").innerHTML = `
    <div class="result-header">
      <h2>${methodLabel}</h2>
    </div>
    <div class="result-cost">Total Financial Exposure: ${formatUSD(total)}</div>
    <div class="result-grid">${pairsHtml}</div>
    <div class="narrative">${data.narrative || ""}</div>
  `;
}

// ── Error and UI states ─────────────────────────────────────────────────────────────────────
function showError(msg) {
  const panel = document.getElementById("result-panel");
  panel.className = "show";
  panel.innerHTML = `<div class="error-box">⚠ ${msg}</div>`;
}

// Toggles buttons on and off so the user can't spam the API
function setSubmitting(on) {
  ["btn-submit", "btn-generate", "btn-clear"].forEach(id => {
    document.getElementById(id).disabled = on;
  });
  const btn = document.getElementById("btn-submit");
  btn.innerHTML = on
    ? `<span class="spinner"></span> Optimizing…`
    : "▶ Find Optimal Assignment";
}

// Resets everything to a clean slate
function resetResult() {
  clearInterval(pollInterval);
  hideQuantumStatus();
  const p = document.getElementById("result-panel");
  p.className = "";
  p.innerHTML = "";
}

// ── Initialization ────────────────────────────────────────────────────────────
// This runs the moment the page loads to set up a 4x4 Classical grid by default.
buildTable(4);
updateModeBadge(4);
updateChips(4);
</script>
</body>
</html>