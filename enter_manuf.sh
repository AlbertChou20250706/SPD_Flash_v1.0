#!/bin/bash
# =============================================================================
#  製造モード投入スクリプト（せいぞう・モード・とうにゅう）/ Enter Manufacturing Mode
#  Flow: sobcontrol → Pc_Ident64 flags.w=manuf → reboot
# -----------------------------------------------------------------------------
#  Designer : Albert.Chou
#  Version  : v1.0.0 (Albert Style)
#  Updated  : 2025-09-22
#  History  :
#    - v1.0.0: First split version with HTML/TXT logs, colors, flags, JP notes.
# =============================================================================
set -euo pipefail
: "${HOME:=/root}"

# =====[ USER EDITABLE / へんこう かのう ]========================================
# 完全相對路徑OK（そうたい）
SOB_BIN_DEFAULT="/opt/deskview/biosset/device/sobcontrol"
PC_IDENT_DEFAULT="${HOME}/Downloads/tools/Pc_Ident64_V4.07.0.0_Linux/Pc_Ident64"

# Flags
DRY_RUN=0

# =====[ FLAGS / きのう フラグ ]=================================================
usage() {
  cat <<'USAGE'
===============================================================================
Enter Manufacturing Mode (Albert Style)
-------------------------------------------------------------------------------
Usage:
  ./enter_manuf.sh [--sob=/path/to/sobcontrol] [--pcident=/path/to/Pc_Ident64] [--dry-run]

Notes:
  * Messages are in English. Comments are Japanese (with reading).
  * Requires root privileges.
  * Reboots automatically after setting manufacturing flag.
===============================================================================
USAGE
}

SOB_BIN="$SOB_BIN_DEFAULT"
PC_IDENT="$PC_IDENT_DEFAULT"
for a in "$@"; do
  case "$a" in
    --sob=*)     SOB_BIN="${a#*=}";;
    --pcident=*) PC_IDENT="${a#*=}";;
    --dry-run)   DRY_RUN=1;;
    -h|--help)   usage; exit 0;;
    *)           echo "[WARN] Unknown flag: $a";;
  esac
done

# =====[ LOG / ログ さくせい ]===================================================
RUN_ID="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="/root/Documents"
LOG_TXT="${LOG_DIR}/enter_manuf_${RUN_ID}.log"
LOG_HTML="${LOG_DIR}/enter_manuf_${RUN_ID}.html"
mkdir -p "$LOG_DIR"; : > "$LOG_TXT"

# =====[ COLORS / いろ ]=========================================================
NC='\033[0m'; RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'; CYA='\033[0;36m'
ts(){ date '+%F %T'; }
_log(){ echo -e "$(ts) | $*" >> "$LOG_TXT"; }
info(){ echo -e "${CYA}[INFO]${NC} $*";  _log "[INFO] $*"; }
pass(){ echo -e "${GRN}[PASS]${NC} $*";  _log "[PASS] $*"; }
warn(){ echo -e "${YEL}[WARN]${NC} $*";  _log "[WARN] $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*";  _log "[FAIL] $*"; }

html_begin(){
  cat > "$LOG_HTML" <<HTML
<!doctype html><html><head><meta charset="utf-8"><title>Enter Manufacturing Mode Report</title>
<style>body{font-family:Arial;margin:20px}h1{border-bottom:2px solid #444;padding-bottom:6px}pre{background:#111;color:#eee;padding:10px;white-space:pre-wrap}</style>
</head><body><h1>Enter Manufacturing Mode (Albert Style)</h1><p>Run: ${RUN_ID}</p>
HTML
}
html_dump(){ echo "<pre>" >> "$LOG_HTML"; sed -e 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' "$LOG_TXT" >> "$LOG_HTML"; echo "</pre>" >> "$LOG_HTML"; }
html_end(){ echo "</body></html>" >> "$LOG_HTML"; }

# =====[ HEADER / せつめい ]=====================================================
echo "===============================================================================" | tee -a "$LOG_TXT"
echo " Enter Manufacturing Mode | Version v1.0.0 | Designer Albert.Chou"            | tee -a "$LOG_TXT"
echo " Log: $(basename "$LOG_TXT")"                                                 | tee -a "$LOG_TXT"
echo "===============================================================================" | tee -a "$LOG_TXT"
html_begin

# =====[ CHECKS / チェック ]=====================================================
[[ -x "$SOB_BIN" ]]  || { fail "sobcontrol not executable: $SOB_BIN"; html_dump; html_end; exit 2; }
[[ -x "$PC_IDENT" ]] || { fail "Pc_Ident64 not executable: $PC_IDENT"; html_dump; html_end; exit 2; }
pass "Paths OK. SOB=$SOB_BIN  PC_IDENT=$PC_IDENT"

# =====[ FLOW / りゅうれき ]=====================================================
echo "REM ========================== STEP 1 / sobcontrol ===========================" | tee -a "$LOG_TXT"
if ((DRY_RUN)); then info "[DRY-RUN] $SOB_BIN start"; else "$SOB_BIN" start | tee -a "$LOG_TXT" || true; fi

# GABI readiness hint（デバイス じゅんび）
if ! ls /dev/gabi* /dev/sob* >/dev/null 2>&1; then
  warn "GABI device nodes not found (maybe unsupported on this OS, e.g., SUSE)."
fi

echo "REM ==================== STEP 2 / Pc_Ident64 manuf ===========================" | tee -a "$LOG_TXT"
if ((DRY_RUN)); then
  info "[DRY-RUN] $PC_IDENT flags.w=manuf"
else
  if "$PC_IDENT" flags.w=manuf | tee -a "$LOG_TXT"; then
    pass "Manufacturing flag written."
  else
    fail "Pc_Ident64 failed to set manuf flag."; html_dump; html_end; exit 2
  fi
fi

echo "REM =========================== STEP 3 / Reboot ==============================" | tee -a "$LOG_TXT"
if ((DRY_RUN)); then
  warn "[DRY-RUN] Skipping reboot."
else
  info "Rebooting now to enter Manufacturing Mode…"
  html_dump; html_end
  if command -v /sbin/reboot >/dev/null 2>&1; then /sbin/reboot; else reboot; fi
fi
