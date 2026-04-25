#!/bin/bash
# =============================================================================
# utils/reporter.sh — CSV & HTML Report Exporter
# CIS GKE Autopilot Benchmark v1.3.0 Audit Tool
# =============================================================================
# Phụ thuộc: AUDIT_RESULTS[], TOTAL_*, PROJECT_ID, CLUSTER_NAME, LOCATION
#             và hàm t() / cis_title() từ i18n.sh (qua logger.sh)
# =============================================================================

# =============================================================================
# print_summary_table — In bảng tổng kết ra terminal
# =============================================================================
print_summary_table() {
    local total=$(( TOTAL_PASS + TOTAL_FAIL + TOTAL_MANUAL + TOTAL_WARN ))
    local pass_pct=0
    [[ $total -gt 0 ]] && pass_pct=$(( TOTAL_PASS * 100 / total ))

    log_header "$(t SUMMARY)"

    echo ""
    printf "  %-14s %-14s %-14s %-14s %-14s\n" \
        "$(t TOTAL_CHECKS)" "✅ PASS" "❌ FAIL" "🔍 MANUAL" "⚠️  WARN"
    printf "  %-14s %-14s %-14s %-14s %-14s\n" \
        "────────────" "────────────" "────────────" "────────────" "────────────"
    printf "  %-14s %-14s %-14s %-14s %-14s\n" \
        "$total" "$TOTAL_PASS" "$TOTAL_FAIL" "$TOTAL_MANUAL" "$TOTAL_WARN"
    echo ""
    echo -e "  $(t PASS_RATE): ${BOLD}${pass_pct}%${NC}"
    echo ""

    if [[ $TOTAL_FAIL -eq 0 ]]; then
        log_pass "$(t ALL_PASS)"
    else
        log_fail "$(printf "$(t HAS_FAIL)" "$TOTAL_FAIL")"
    fi
    echo ""
}

# =============================================================================
# export_csv <output_file>
# =============================================================================
export_csv() {
    local output_file="${1:-output/gke_audit_$(date +%Y%m%d_%H%M%S).csv}"
    mkdir -p "$(dirname "$output_file")"

    {
        printf '%s,%s,%s,%s\n' \
            "$(t COL_CIS)" "$(t COL_TITLE)" "$(t COL_RESULT)" "$(t COL_DETAIL)"
        for entry in "${AUDIT_RESULTS[@]}"; do
            IFS='§' read -r cis_id title status detail <<< "$entry"
            cis_id="${cis_id//\"/\"\"}"
            title="${title//\"/\"\"}"
            detail="${detail//\"/\"\"}"
            printf '"%s","%s","%s","%s"\n' "$cis_id" "$title" "$status" "$detail"
        done
    } > "$output_file"

    log_pass "$(printf "$(t REPORT_CSV)" "$output_file")"
}

# =============================================================================
# export_html <output_file>
# =============================================================================
export_html() {
    local output_file="${1:-output/gke_audit_$(date +%Y%m%d_%H%M%S).html}"
    mkdir -p "$(dirname "$output_file")"

    local total=$(( TOTAL_PASS + TOTAL_FAIL + TOTAL_MANUAL + TOTAL_WARN ))
    local pass_pct=0
    [[ $total -gt 0 ]] && pass_pct=$(( TOTAL_PASS * 100 / total ))
    local run_time
    run_time=$(date '+%d/%m/%Y %H:%M:%S')
    local lang_label
    [[ "$AUDIT_LANG" == "en" ]] && lang_label="English (en)" || lang_label="Tiếng Việt (vi)"

    cat > "$output_file" << HTMLEOF
<!DOCTYPE html>
<html lang="${AUDIT_LANG:-vi}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CIS GKE Benchmark v1.3.0 — Audit Report</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');
    :root {
      --bg-primary:#0f1117;--bg-secondary:#1a1d27;--bg-card:#1e2235;--bg-hover:#252a3d;
      --border:#2d3354;--text-primary:#e2e8f0;--text-muted:#8892a4;
      --green:#22c55e;--green-bg:rgba(34,197,94,.12);
      --red:#ef4444;--red-bg:rgba(239,68,68,.12);
      --yellow:#f59e0b;--yellow-bg:rgba(245,158,11,.12);
      --blue:#3b82f6;--blue-bg:rgba(59,130,246,.12);
      --purple:#a855f7;--cyan:#06b6d4;--accent:#6366f1;
    }
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Inter',sans-serif;background:var(--bg-primary);color:var(--text-primary);min-height:100vh;padding:2rem;line-height:1.6}
    /* Header */
    .report-header{background:linear-gradient(135deg,#1e2235,#252a3d 50%,#1a1d27);border:1px solid var(--border);border-radius:16px;padding:2.5rem;margin-bottom:2rem;position:relative;overflow:hidden}
    .report-header::before{content:'';position:absolute;top:-50%;right:-10%;width:300px;height:300px;background:radial-gradient(circle,rgba(99,102,241,.15),transparent 70%);pointer-events:none}
    .report-header h1{font-size:1.8rem;font-weight:700;background:linear-gradient(90deg,#6366f1,#06b6d4);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;margin-bottom:.5rem}
    .report-header .subtitle{color:var(--text-muted);font-size:.95rem}
    .report-header .meta{margin-top:1.2rem;display:flex;gap:2rem;flex-wrap:wrap}
    .meta-item{display:flex;flex-direction:column;gap:2px}
    .meta-label{color:var(--text-muted);font-size:.75rem;text-transform:uppercase;letter-spacing:.05em}
    .meta-value{color:var(--text-primary);font-size:.9rem;font-weight:500;font-family:'JetBrains Mono',monospace}
    /* Summary cards */
    .summary-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:1rem;margin-bottom:2rem}
    .summary-card{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.2rem 1.5rem;text-align:center;transition:transform .2s,border-color .2s}
    .summary-card:hover{transform:translateY(-2px)}
    .summary-card.pass{border-color:rgba(34,197,94,.4);background:linear-gradient(135deg,var(--bg-card),rgba(34,197,94,.05))}
    .summary-card.fail{border-color:rgba(239,68,68,.4);background:linear-gradient(135deg,var(--bg-card),rgba(239,68,68,.05))}
    .summary-card.manual{border-color:rgba(245,158,11,.4);background:linear-gradient(135deg,var(--bg-card),rgba(245,158,11,.05))}
    .summary-card.warn{border-color:rgba(59,130,246,.4);background:linear-gradient(135deg,var(--bg-card),rgba(59,130,246,.05))}
    .summary-card .count{font-size:2.5rem;font-weight:700;line-height:1;margin-bottom:.3rem}
    .summary-card.pass .count{color:var(--green)}
    .summary-card.fail .count{color:var(--red)}
    .summary-card.manual .count{color:var(--yellow)}
    .summary-card.warn .count{color:var(--blue)}
    .summary-card .label{color:var(--text-muted);font-size:.8rem;font-weight:500;text-transform:uppercase;letter-spacing:.05em}
    /* Progress */
    .progress-section{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;margin-bottom:2rem}
    .progress-label{display:flex;justify-content:space-between;margin-bottom:.6rem;font-size:.9rem}
    .progress-bar-bg{height:10px;background:var(--bg-secondary);border-radius:999px;overflow:hidden}
    .progress-bar-fill{height:100%;border-radius:999px;background:linear-gradient(90deg,#22c55e,#06b6d4)}
    /* Table */
    .table-section{background:var(--bg-card);border:1px solid var(--border);border-radius:16px;overflow:hidden;margin-bottom:2rem}
    .table-section-header{padding:1.2rem 1.5rem;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:.8rem}
    .table-section-header h2{font-size:1rem;font-weight:600}
    .section-badge{font-size:.72rem;font-weight:600;padding:2px 8px;border-radius:999px;font-family:'JetBrains Mono',monospace}
    table{width:100%;border-collapse:collapse;font-size:.875rem}
    thead th{background:var(--bg-secondary);padding:.8rem 1rem;text-align:left;font-size:.75rem;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--text-muted);border-bottom:1px solid var(--border)}
    tbody tr{border-bottom:1px solid rgba(45,51,84,.6);transition:background .15s}
    tbody tr:hover{background:var(--bg-hover)}
    tbody tr:last-child{border-bottom:none}
    tbody td{padding:.85rem 1rem;vertical-align:top}
    .cis-id{font-family:'JetBrains Mono',monospace;font-size:.8rem;font-weight:600;color:var(--cyan);white-space:nowrap}
    .detail-text{color:var(--text-muted);font-size:.82rem;line-height:1.5}
    /* Status badges */
    .status-badge{display:inline-flex;align-items:center;gap:5px;padding:3px 10px;border-radius:999px;font-size:.75rem;font-weight:700;letter-spacing:.05em;white-space:nowrap}
    .badge-PASS{background:var(--green-bg);color:var(--green);border:1px solid rgba(34,197,94,.3)}
    .badge-FAIL{background:var(--red-bg);color:var(--red);border:1px solid rgba(239,68,68,.3)}
    .badge-MANUAL{background:var(--yellow-bg);color:var(--yellow);border:1px solid rgba(245,158,11,.3)}
    .badge-WARN{background:var(--blue-bg);color:var(--blue);border:1px solid rgba(59,130,246,.3)}
    /* Footer */
    .report-footer{text-align:center;color:var(--text-muted);font-size:.8rem;padding:1rem}
    .report-footer a{color:var(--accent);text-decoration:none}
    .lang-badge{display:inline-flex;align-items:center;gap:4px;background:rgba(99,102,241,.15);color:var(--accent);border:1px solid rgba(99,102,241,.3);padding:2px 8px;border-radius:999px;font-size:.72rem;font-weight:600}
  </style>
</head>
<body>

<div class="report-header">
  <h1>🛡️ CIS GKE Benchmark v1.3.0 — Audit Report</h1>
  <p class="subtitle">$(t HTML_SUBTITLE)</p>
  <div class="meta">
    <div class="meta-item">
      <span class="meta-label">Project ID</span>
      <span class="meta-value">${PROJECT_ID}</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Cluster</span>
      <span class="meta-value">${CLUSTER_NAME}</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Location</span>
      <span class="meta-value">${LOCATION}</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">$(t HTML_TIME_LABEL)</span>
      <span class="meta-value">${run_time}</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Language</span>
      <span class="meta-value"><span class="lang-badge">🌐 ${lang_label}</span></span>
    </div>
  </div>
</div>

<div class="summary-grid">
  <div class="summary-card pass">
    <div class="count">${TOTAL_PASS}</div>
    <div class="label">✅ Pass</div>
  </div>
  <div class="summary-card fail">
    <div class="count">${TOTAL_FAIL}</div>
    <div class="label">❌ Fail</div>
  </div>
  <div class="summary-card manual">
    <div class="count">${TOTAL_MANUAL}</div>
    <div class="label">🔍 Manual</div>
  </div>
  <div class="summary-card warn">
    <div class="count">${TOTAL_WARN}</div>
    <div class="label">⚠️ Warn</div>
  </div>
  <div class="summary-card" style="border-color:rgba(168,85,247,.4);background:linear-gradient(135deg,var(--bg-card),rgba(168,85,247,.05))">
    <div class="count" style="color:var(--purple)">${total}</div>
    <div class="label">📋 $(t TOTAL_CHECKS)</div>
  </div>
</div>

<div class="progress-section">
  <div class="progress-label">
    <span>$(t PASS_RATE)</span>
    <span style="color:var(--green);font-weight:600">${pass_pct}%</span>
  </div>
  <div class="progress-bar-bg">
    <div class="progress-bar-fill" style="width:${pass_pct}%"></div>
  </div>
</div>

<div class="table-section">
  <div class="table-section-header">
    <h2>$(t HTML_TABLE_TITLE)</h2>
    <span class="section-badge" style="background:rgba(99,102,241,.15);color:var(--accent)">${total} checks</span>
  </div>
  <table>
    <thead>
      <tr>
        <th>$(t COL_CIS)</th>
        <th>$(t COL_TITLE)</th>
        <th>$(t COL_RESULT)</th>
        <th>$(t COL_DETAIL)</th>
      </tr>
    </thead>
    <tbody>
HTMLEOF

    for entry in "${AUDIT_RESULTS[@]}"; do
        IFS='§' read -r cis_id title status detail <<< "$entry"
        cis_id_esc="${cis_id//&/&amp;}"
        title_esc="${title//&/&amp;}"; title_esc="${title_esc//</&lt;}"; title_esc="${title_esc//>/&gt;}"
        detail_esc="${detail//&/&amp;}"; detail_esc="${detail_esc//</&lt;}"; detail_esc="${detail_esc//>/&gt;}"
        cat >> "$output_file" << ROWEOF
      <tr>
        <td><span class="cis-id">${cis_id_esc}</span></td>
        <td>${title_esc}</td>
        <td><span class="status-badge badge-${status}">${status}</span></td>
        <td><span class="detail-text">${detail_esc}</span></td>
      </tr>
ROWEOF
    done

    cat >> "$output_file" << HTMLEOF
    </tbody>
  </table>
</div>

<div class="report-footer">
  <p>$(t HTML_FOOTER) — NT542.Q22, Nhóm 11 &bull; ${run_time}</p>
  <p style="margin-top:4px">
    <a href="https://www.cisecurity.org/benchmark/kubernetes" target="_blank">CIS Google Kubernetes Engine Autopilot Benchmark v1.3.0</a>
  </p>
</div>

</body>
</html>
HTMLEOF

    log_pass "$(printf "$(t REPORT_HTML)" "$output_file")"
}
