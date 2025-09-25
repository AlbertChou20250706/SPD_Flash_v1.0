# SPD_Flash_v1.0
SPD Flash – Albert README (JP-notes / EN-messages)
# SPD Flash – Albert README (JP-notes / EN-messages)

> **設計（せっけい）/ Designer:** Albert.Chou  
> **版（ばん）/ Version:** v1.0 (README for split mode)  
> **対象（たいしょう）:** 2-script flow — `enter_manuf.sh` → reboot → `flash_spd_manual.sh`  
> **出力（しゅつりょく）:** TXT + HTML logs under `/root/Documents/`  
> **メッセージ:** user-facing messages are **English**; comments in scripts are **Japanese (with reading)**

---

## 0) 目的（もくてき）/ Purpose

- **分割実行（ぶんかつ じっこう）**:
  1) 先に **Manufacturing Mode**（製造モード）へ入れる → 自動再起動  
  2) 再起動後、手動で **SPD 書き込み**（`SMBVIEW64 -INI …`）＋ 任意で `-SCD` 検証

- **Albert Style**:  
  - すべて相対パスOK  
  - 明確フラグ、色つき出力、時刻スタンプ  
  - **TXT/HTML** の二重ログ（/root/Documents）

---

## 1) フォルダ構成（こうせい）/ Layout

```
<toolkit>/
├─ enter_manuf.sh              # 1st script: enter manufacturing mode + reboot
├─ flash_spd_manual.sh         # 2nd script: start GABI → flash SPD → [optional] verify
├─ memory.ini                  # your SPD control file (editable)
└─ (optional) tools/           # Pc_Ident64 / SMBVIEW64 if you keep them here
```

> You may also keep vendor tools in your usual locations, e.g. `~/Downloads/tools/…` or `/opt/deskview/…`.

---

## 2) 前提（ぜんてい）/ Prerequisites

- Run as **root** (or via `sudo`).
- **GABI** driver (for `sobcontrol`) must be supported on the running OS/kernel.  
  - RHEL 8/9 family (Rocky/Alma/RHEL) is typically OK.  
  - **SUSE** may **not** be supported by vendor GABI — see Troubleshooting.

---

## 3) 使用手順（しよう てじゅん）/ How to Use

### Step A — Enter Manufacturing Mode (auto reboot)

```bash
sudo ./enter_manuf.sh   --sob=/opt/deskview/biosset/device/sobcontrol   --pcident=~/Downloads/tools/Pc_Ident64_V4.07.0.0_Linux/Pc_Ident64
```

- What it does:
  1) `sobcontrol start`（GABI 起動）
  2) `Pc_Ident64 flags.w=manuf`（製造モード書き込み）
  3) `reboot`（自動再起動）

- After reboot, POST 画面に **“Manufacturing Mode Active”** が表示されるはず。

### Step B — Flash SPD (manual)

```bash
sudo ./flash_spd_manual.sh   --sob=/opt/deskview/biosset/device/sobcontrol   --smbview=~/Downloads/tools/SMBVIEW_v2.85/SMBVIEW64   --ini=./memory.ini   --verify               # その場で -SCD 検証したいときだけ付ける
```

- What it does:
  1) `sobcontrol start`
  2) **Deploy INI** into SMBVIEW folder as `memory.ini` and **`SMBVIEW.INI`**, strip CRLF
  3) Try multiple syntaxes:  
     `-INI="SMBVIEW.INI"`, `-INI=SMBVIEW.INI`, `-INI "memory.ini"`, `-ini=SMBVIEW.INI`, and **fallback: no-arg** (so SMBVIEW loads `SMBVIEW.INI`)
  4) (optional) `-SCD` verify

> ⚠️ If your `memory.ini` programs **MemMark=1**, **you must reboot once before reading SPD** (`-SCD`) — vendor rule.

---

## 4) スクリプトのフラグ / Script Flags

### `enter_manuf.sh`
- `--sob=/path/to/sobcontrol` (default: `/opt/deskview/biosset/device/sobcontrol`)
- `--pcident=/path/to/Pc_Ident64` (default: `~/Downloads/tools/Pc_Ident64_V4.07.0.0_Linux/Pc_Ident64`)
- `--dry-run` (preview only; no changes)
- `-h|--help`

### `flash_spd_manual.sh`
- `--sob=/path/to/sobcontrol`  
- `--smbview=/path/to/SMBVIEW64`  
- `--ini=/path/to/memory.ini` (relative OK)  
- `--verify` (run `-SCD` after flashing)  
- `--dry-run`  
- `-h|--help`

---

## 5) ログ / Logs

- **TXT** and **HTML** logs are saved to `/root/Documents/`:
  - `enter_manuf_YYYYMMDD_HHMMSS.{log,html}`
  - `flash_spd_YYYYMMDD_HHMMSS.{log,html}`

- Colorized console output shows: **[INFO], [PASS], [WARN], [FAIL]** with timestamps.

---

## 6) 検証ロジック（けんしょう）/ Verification Logic

1) Manufacturing Mode:
   - After Step A + reboot, POST should display **“Manufacturing Mode Active”**.  
   - In OS, `sobcontrol start` then `SMBVIEW64 -SCD` should return **Ret=0** (if you **haven’t** written MemMark yet).

2) After flashing:
   - If `MemMark=1` was programmed, **do not expect SPD to be readable in the same boot**. Reboot once, then `-SCD`.

3) SEL Logs:
   - Some platforms produce “Non Certified Memory Module detected” entries if SPD doesn’t yet match OEM expectations.  
   - Clear SEL, then repeat boot/verify after successful programming to confirm no new entries appear.  
   - If customer policy says **MemMark=1 should not generate DIMM SEL**, ensure programming completed (rc=0) and rebooted before checking.

---

## 7) よくある問題（トラブルシュート）/ Troubleshooting

### A. SMBVIEW64 just prints the header and hangs
**Symptom:** Only `SMBUS/I2C VIEWER V2.85` appears; no progress.

**Cause:** GABI not ready / unsupported on this OS (very common on **SUSE**).

**Fix:**
1. Ensure GABI device nodes exist:
   ```bash
   ls -l /dev/gabi* /dev/sob* 2>/dev/null || echo "no GABI device nodes"
   /opt/deskview/biosset/device/sobcontrol start
   ```
2. If nodes never appear on SUSE, **use an OS LiveUSB that vendor supports** (RHEL/Rocky/Alma) to perform flashing, or obtain a **SUSE-specific GABI kmod/DKMS** from vendor.

---

### B. `No Device present` / return code 5
**Meaning:** SMBVIEW64 cannot reach the bus/driver.  
**Fix:** `sobcontrol start` first; verify `/dev/gabi*` exists; if still failing on SUSE, see A.

---

### C. `Read INI file failed`
**Meaning:** INI unreadable (wrong place or CRLF).

**Fix:** The scripts already:
- copy your INI into the **SMBVIEW folder**, as both `memory.ini` and `SMBVIEW.INI`
- strip CRLF via `sed -i 's/
$//' ...`

If running manually, do the same and use **uppercase `-INI`**:
```bash
cd ~/Downloads/tools/SMBVIEW_v2.85
cp /path/to/memory.ini ./SMBVIEW.INI
sed -i 's/
$//' SMBVIEW.INI
sudo ./SMBVIEW64 -INI=SMBVIEW.INI
```

---

### D. `Ret = 61 (0x3D) Manufacturing mode is FALSE`
Two possibilities:
1) You never entered Manufacturing Mode → run **Step A** again.  
2) You **just wrote MemMark** and try to read SPD in the same boot → **reboot once**, then `-SCD`.

---

### E. Argument accepted but nothing happens with `-ini=...`
Some builds ignore lowercase `-ini`. Use **uppercase `-INI`**.  
Scripts try multiple syntaxes automatically (including a **no-arg** fallback that loads `SMBVIEW.INI`).

---

### F. SUSE / GABI unsupported (officially)
- If `sobcontrol start` shows OK but **no `/dev/gabi*`** appears, and SMBVIEW64 never proceeds:  
  - **Boot a supported LiveUSB** (RHEL/Rocky/Alma), run both steps there.  
  - Or install **vendor-provided SUSE kmod/DKMS** (if available), with matching `kernel-headers`, then `modprobe` and retry.  
- This is a **driver coverage** issue, not an INI or syntax bug.

---

## 8) ベストプラクティス / Best Practices

- Always **enter Manufacturing Mode and reboot** before programming.  
- Keep tools & `memory.ini` in a **single toolkit folder** when possible; avoid moving folders between Step A and B.  
- For repeatability, log every run; attach the HTML to your build record.  
- After successful programming with `MemMark=1`, **reboot once** before reading SPD or checking SEL.

---

## 9) 進版情報（しんぱん）/ Changelog (README)

- v1.0 (2025-09-22): Initial Albert README for split-mode; adds SUSE/GABI guidance, full flows, flags, verification & error matrix.

---

## 10) 連絡先（れんらくさき）/ Hand-off Notes

- 保守（ほしゅ）・引継（ひきつぎ）用に：  
  - 保存パス `/root/Documents/enter_manuf_*.{log,html}` と `/root/Documents/flash_spd_*.{log,html}`  
  - 成功判定：  
    - Step A：POST に “Manufacturing Mode Active” 表示／`-SCD` (pre-flash) 可読  
    - Step B：プログラム rc=0／（必要なら）再起動後 `-SCD` で Ret=0  
  - OS 非対応時（SUSE/GABI）SOP：**LiveUSB（RHEL 系）で実施** or ベンダー kmod

---

### Quick Command Recap

```bash
# Step A
sudo ./enter_manuf.sh --sob=/opt/deskview/biosset/device/sobcontrol                       --pcident=~/Downloads/tools/Pc_Ident64_V4.07.0.0_Linux/Pc_Ident64
# (auto reboot)

# Step B
sudo ./flash_spd_manual.sh --sob=/opt/deskview/biosset/device/sobcontrol                            --smbview=~/Downloads/tools/SMBVIEW_v2.85/SMBVIEW64                            --ini=./memory.ini --verify
```
