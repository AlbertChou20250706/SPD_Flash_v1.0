#!/bin/bash
# =============================================================================
#  SPD かきこみスクリプト（かきこみ）/ Program SPD (Manual Phase)
#  Flow: sobcontrol → deploy INI → SMBVIEW64 -INI (multi-syntax) → [optional] -SCD
# -----------------------------------------------------------------------------
#  Designer : Albert.Chou
#  Version  : v1.0.0 (Albert Style)
#  Updated  : 2025-09-22
#  History  :
#    - v1.0.0: Split manual phase; JP notes; HTML/TXT logs; multi -INI fallback.
# =============================================================================
set -euo pipefail
: "${HOME:=/root}"

# =====[ USER EDITABLE / へんこう かのう ]========================================
SOB_BIN_DEFAULT="/opt/deskview/biosset/device/sobcontrol"
SMB_BIN_DEFAULT="${HOME}/Downloads/tools/SMBVIEW_v2.85/SMBVIEW64"
INI_DEFAULT="./memory.ini"      # 相対OK

DO_VERIFY=0    # 1 = run -SCD after programming（MemMark=1 のばあいは再起動ごに）

# =====[ FLAGS / きのう フラグ ]=================================================
usage(){
  cat <<'USAGE'
===============================================================================
Flash SPD (Manual) – Albert Style
-------------------------------------------------------------------------------
Usage:
  ./flash_spd_manual.sh [--sob=/path/to/sobcontrol] [--smbview=/path/to/SMBVIEW64]
                        [--ini=memory.ini] [--verify] [--dry-run]

Notes:
  * Run this AFTER you entered Manufacturing Mode and rebooted.
  * Script deploys INI into SMBVIEW folder as memory.ini & SMBVIEW.INI, strips CRLF,
    and tries multiple -INI/-ini syntaxes (final fallback: no-arg SMBVIEW64).
  * Messages are in English. Comments are Japanese (with reading).
===============================================================================
USAGE
}

SOB_BIN="$SOB_BIN_DEFAULT"
SMB_BIN="$SMB_BIN_DEFAULT"
INI_PATH="$INI_DEFAULT"
DRY_RUN=0

for a in "$@"; do
  case "$a" in
    --sob=*)     SOB_BIN="${a#*=}";;
    --smbview=*) SMB_BIN="${a#*=}";;
    --ini=*)     INI_PATH="${a#*=}";;
    --verify)    DO_VERIFY=1;;
    --dry-run)   DRY_RUN=1;;
    -h|--help)   usage; exit 0;;
    *)           echo "[WARN] Unknown flag: $a";;
  esac
done

# =====[ LOG / ログ ]============================================================
RUN_ID="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="/root/Documents"
LOG_TXT="${LOG_DIR}/flash_spd_${RUN_ID}.log"
LOG_HTML="${LOG_DIR}/flash_spd_${RUN_ID}.html"
mkdir -p "$LOG_DIR"; : > "$LOG_TXT"

# =====[ COLORS ]================================================================
NC='\033[0m'; RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'; CYA='\033[0;36m'
ts(){ date '+%F %T'; }
_log(){ echo -e "$(ts) | $*" >> "$LOG_TXT"; }
info(){ echo -e "${CYA}[INFO]${NC} $*";  _log "[INFO] $*"; }
pass(){ echo -e "${GRN}[PASS]${NC} $*";  _log "[PASS] $*"; }
warn(){ echo -e "${YEL}[WARN]${NC} $*";  _log "[WARN] $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*";  _log "[FAIL] $*"; }

html_begin(){
  cat > "$LOG_HTML" <<HTML
<!doctype html><html><head><meta charset="utf-8"><title>Flash SPD Report</title>
<style>body{font-family:Arial;margin:20px}h1{border-bottom:2px solid #444;padding-bottom:6px}pre{background:#111;color:#eee;padding:10px;white-space:pre-wrap}</style>
</head><body><h1>Flash SPD (Manual) – Albert Style</h1><p>Run: ${RUN_ID}</p>
HTML
}
html_dump(){ echo "<pre>" >> "$LOG_HTML"; sed -e 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' "$LOG_TXT" >> "$LOG_HTML"; echo "</pre>" >> "$LOG_HTML"; }
html_end(){ echo "</body></html>" >> "$LOG_HTML"; }

# =====[ HEADER ]================================================================
echo "===============================================================================" | tee -a "$LOG_TXT"
echo " Flash SPD (Manual) | Version v1.0.0 | Designer Albert.Chou"                   | tee -a "$LOG_TXT"
echo " Log: $(basename "$LOG_TXT")"                                                 | tee -a "$LOG_TXT"
echo "===============================================================================" | tee -a "$LOG_TXT"
html_begin

# =====[ CHECKS ]================================================================
[[ -x "$SOB_BIN" ]]  || { fail "sobcontrol not executable: $SOB_BIN"; html_dump; html_end; exit 2; }
[[ -x "$SMB_BIN" ]]  || { fail "SMBVIEW64 not executable: $SMB_BIN"; html_dump; html_end; exit 2; }
[[ -f "$INI_PATH" ]] || { fail "INI not found: $INI_PATH"; html_dump; html_end; exit 2; }
pass "Paths OK. SOB=$SOB_BIN  SMBVIEW=$SMB_BIN  INI=$INI_PATH"

# =====[ STEP 1 / sobcontrol ]===================================================
echo "REM ========================== STEP 1 / sobcontrol ===========================" | tee -a "$LOG_TXT"
if ((DRY_RUN)); then info "[DRY-RUN] $SOB_BIN start"; else "$SOB_BIN" start | tee -a "$LOG_TXT" || true; fi
if ! ls /dev/gabi* /dev/sob* >/dev/null 2>&1; then
  warn "GABI device nodes not found. If this is SUSE, vendor GABI driver may be unsupported."
fi

# =====[ STEP 2 / deploy INI ]===================================================
echo "REM =========================== STEP 2 / INI deploy ==========================" | tee -a "$LOG_TXT"
SMB_DIR="$(cd "$(dirname "$SMB_BIN")" && pwd)"
SMB_EXE="$(basename "$SMB_BIN")"
INI_ABS="$(cd "$(dirname "$INI_PATH")" && pwd)/$(basename "$INI_PATH")"

if ((DRY_RUN)); then
  info "[DRY-RUN] Deploy $INI_ABS → ${SMB_DIR}/{memory.ini,SMBVIEW.INI}"
else
  install -m 0644 -D "$INI_ABS" "${SMB_DIR}/memory.ini"
  cp -f "${SMB_DIR}/memory.ini" "${SMB_DIR}/SMBVIEW.INI"
  sed -i 's/\r$//' "${SMB_DIR}/memory.ini" "${SMB_DIR}/SMBVIEW.INI" 2>/dev/null || true
fi
pass "INI ready at SMBVIEW folder."

# =====[ STEP 3 / program SPD ]==================================================
echo "REM ======================== STEP 3 / Program SPD ============================" | tee -a "$LOG_TXT"
cd "$SMB_DIR"
SYNTAXES=(
  '-INI="SMBVIEW.INI"'
  '-INI=SMBVIEW.INI'
  '-INI="memory.ini"'
  '-INI memory.ini'
  '-ini=SMBVIEW.INI'
  ''
)

PRC=1
for s in "${SYNTAXES[@]}"; do
  info "Trying syntax: ${s:-<none/SMBVIEW.INI>}"
  if ((DRY_RUN)); then
    info "[DRY-RUN] ./${SMB_EXE} $s"
    PRC=0; break
  else
    set +e
    ./"$SMB_EXE" $s
    PRC=$?
    set -e
    if [[ $PRC -eq 0 ]]; then
      pass "SPD programming completed (rc=0) with syntax: ${s:-<none>}"
      break
    fi
  fi
done
[[ $PRC -eq 0 ]] || { fail "All syntaxes failed (last rc=$PRC). Check GABI & INI."; html_dump; html_end; exit 3; }

# =====[ STEP 4 / optional verify ]==============================================
echo "REM =========================== STEP 4 / Verify ==============================" | tee -a "$LOG_TXT"
if (( DO_VERIFY )); then
  info "Running SMBVIEW64 -SCD for verification…"
  if ((DRY_RUN)); then
    info "[DRY-RUN] ./${SMB_EXE} -SCD"
  else
    set +e
    ./"$SMB_EXE" -SCD
    VRC=$?
    set -e
    if [[ $VRC -eq 0 ]]; then
      pass "Verify (-SCD) OK."
    else
      warn "Verify rc=$VRC. If MemMark=1 was written, reboot once then run -SCD again."
    fi
  fi
else
  info "Skip verify. Tip: If MemMark=1, reboot once before running -SCD."
fi

# =====[ FOOTER / HTML ]=========================================================
html_dump; html_end
pass "TXT: $LOG_TXT"
pass "HTML: $LOG_HTML"
