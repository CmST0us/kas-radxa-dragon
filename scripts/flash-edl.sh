#!/usr/bin/env bash
#
# flash-edl.sh — 用 edl-ng 在 EDL 模式下刷写 Radxa Dragon Q6A (QCS6490) 固件
#
# 参考 flange 的 builder/flash.py:QualcommFlashStrategy，适配本 kas/Yocto 工程。
#
# 固件包：SPI NOR 固件、UFS HLOS 镜像、firehose loader 均取自 Radxa 官方固件包
#   https://dl.radxa.com/dragon/q6a/images/dragon-q6a_flat_build_wp_260120.zip
# 首次运行会自动下载并解压到 scripts/firmware/（已 gitignore）。脚本只引用工程内路径，
# 不依赖本机任何外部路径。
#
# 两类刷写目标：
#   - spinor : 引导固件（XBL/EDK2 等 SPI NOR），来自固件包的 spinor 目录。
#   - ufs    : 系统盘（HLOS 分区），来自固件包的 ufs_hlos 目录。
#              如需刷 kas 自构建的系统镜像，用 UFS_DIR 指向 deploy/images/<machine>。
#
# 进入 EDL 模式：断电 → 按住 EDL 按钮 → 用 USB3 线连接主机上电
# （设备枚举为 "Qualcomm HS-USB QDLoader 9008"，VID:PID 05c6:9008）。
#
# 用法（在本仓库根目录执行）:
#   scripts/flash-edl.sh detect            # 探测 EDL 设备
#   scripts/flash-edl.sh fetch             # 仅下载并解压固件包
#   scripts/flash-edl.sh spinor            # 刷引导固件 (SPI NOR, bring-up)
#   scripts/flash-edl.sh ufs               # 刷系统盘 (UFS HLOS)
#   scripts/flash-edl.sh all               # 先 spinor 再 ufs，最后 reset
#   scripts/flash-edl.sh reset             # 复位设备退出 EDL
#
# 可用环境变量覆盖默认值（见下方“配置”）。
set -euo pipefail

# ─────────────────────────── 配置 ───────────────────────────
# REPO_DIR 由脚本自身位置推导，不写死本机路径。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MACHINE="${MACHINE:-qcs6490-radxa-dragon-q6a}"
EDL_USB="05c6:9008"                            # Qualcomm HS-USB QDLoader 9008

# 官方固件包与工程内缓存目录（一切外部资源下载进工程，不引用工程外路径）。
# 只在刷固件时用到，放在 scripts/ 下（不污染仓库根）。
FW_URL="${FW_URL:-https://dl.radxa.com/dragon/q6a/images/dragon-q6a_flat_build_wp_260120.zip}"
FW_DIR="${FW_DIR:-$SCRIPT_DIR/firmware}"

# 系统盘镜像来源：默认用固件包的 ufs_hlos；要刷 kas 自构建镜像则设
#   UFS_DIR=build/tmp-glibc/deploy/images/$MACHINE
UFS_DIR="${UFS_DIR:-}"                          # 留空 = 自动定位固件包内 ufs_hlos

# edl-ng 可执行文件定位顺序：EDL_NG 显式覆盖 → scripts/edl-ng/ 内已下载 → PATH
# （如 /usr/bin/edl-ng）→ 自动下载到 scripts/edl-ng/。
EDL_NG="${EDL_NG:-}"
EDL_NG_DIR="${EDL_NG_DIR:-$SCRIPT_DIR/edl-ng}"
EDL_NG_URL="${EDL_NG_URL:-https://dl.radxa.com/q6a/images/edl-ng-dist.zip}"

# 若 USB 访问需要 root，设 SUDO=sudo 运行（或配 udev 规则）。
SUDO="${SUDO:-}"

# ─────────────────────────── 输出辅助 ───────────────────────────
if [ -t 1 ]; then C_B='\033[1;34m'; C_G='\033[0;32m'; C_Y='\033[1;33m'; C_R='\033[1;31m'; C_W='\033[0;37m'; C_0='\033[0m'
else C_B=''; C_G=''; C_Y=''; C_R=''; C_W=''; C_0=''; fi
_hdr()  { printf "\n${C_W}══════════════════════════════════════════════════════════${C_0}\n${C_W} %s${C_0}\n${C_W}══════════════════════════════════════════════════════════${C_0}\n\n" "$1"; }
_step() { printf "${C_B}▸ %s${C_0}\n" "$1"; }
_ok()   { printf "${C_G}  ✓ %s${C_0}\n" "$1"; }
_warn() { printf "${C_Y}  ⚠ %s${C_0}\n" "$1"; }
_err()  { printf "${C_R}  ✗ %s${C_0}\n" "$1" >&2; }
_info() { printf "${C_W}  · %s${C_0}\n" "$1"; }
die()   { _err "$1"; exit 1; }

# ─────────────────────────── 固件包获取 ───────────────────────────
ensure_firmware() {
    mkdir -p "$FW_DIR"
    if find "$FW_DIR" -name prog_firehose_ddr.elf -print -quit 2>/dev/null | grep -q .; then
        return
    fi
    local zip="$FW_DIR/$(basename "$FW_URL")"
    if [ ! -f "$zip" ]; then
        _step "下载固件包 → scripts/firmware/$(basename "$FW_URL")"
        if command -v curl >/dev/null 2>&1; then
            curl -fL --progress-bar -o "$zip" "$FW_URL"
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$zip" "$FW_URL"
        else
            die "需要 curl 或 wget 才能下载固件包"
        fi
    fi
    _step "解压固件包 → scripts/firmware/"
    command -v unzip >/dev/null 2>&1 || die "需要 unzip 才能解压固件包"
    unzip -q -o "$zip" -d "$FW_DIR"
    find "$FW_DIR" -name prog_firehose_ddr.elf -print -quit 2>/dev/null | grep -q . \
        || die "固件包内未找到 prog_firehose_ddr.elf（URL 或包结构可能有变）"
    _ok "固件包就绪"
}

# 在固件包内自动定位（不假设具体子目录层级）
locate_loader()  { find "$FW_DIR" -name prog_firehose_ddr.elf -print -quit 2>/dev/null; }
locate_ufs_dir() { find "$FW_DIR" -type d -name 'ufs_hlos' -print -quit 2>/dev/null; }

# ─────────────────────────── 工具与设备 ───────────────────────────
# 仅向 stdout 输出最终可执行路径；进度/诊断一律走 stderr（结果会被 $() 捕获）。
ensure_edl_ng() {
    # 1) 显式覆盖
    if [ -n "$EDL_NG" ]; then
        [ -x "$EDL_NG" ] || die "EDL_NG 指定的文件不可执行: $EDL_NG"
        echo "$EDL_NG"; return
    fi
    # 2) 工程内已下载
    local bin
    bin="$(find "$EDL_NG_DIR" -type f -name edl-ng -print -quit 2>/dev/null || true)"
    if [ -n "$bin" ]; then chmod +x "$bin" 2>/dev/null || true; echo "$bin"; return; fi
    # 3) PATH（如 /usr/bin/edl-ng）
    if command -v edl-ng >/dev/null 2>&1; then command -v edl-ng; return; fi
    # 4) 自动下载到 scripts/edl-ng/
    _step "下载 edl-ng → scripts/edl-ng/" >&2
    mkdir -p "$EDL_NG_DIR"
    local zip="$EDL_NG_DIR/$(basename "$EDL_NG_URL")"
    if [ ! -f "$zip" ]; then
        if command -v curl >/dev/null 2>&1; then curl -fL --progress-bar -o "$zip" "$EDL_NG_URL" >&2
        elif command -v wget >/dev/null 2>&1; then wget -O "$zip" "$EDL_NG_URL" >&2
        else die "需要 curl 或 wget 才能下载 edl-ng"; fi
    fi
    command -v unzip >/dev/null 2>&1 || die "需要 unzip 才能解压 edl-ng"
    unzip -q -o "$zip" -d "$EDL_NG_DIR" >&2
    bin="$(find "$EDL_NG_DIR" -type f -name edl-ng -print -quit 2>/dev/null || true)"
    [ -n "$bin" ] || die "edl-ng 下载/解压后未找到可执行文件 edl-ng（检查 EDL_NG_URL 或包结构）"
    chmod +x "$bin"
    echo "$bin"
}

# 被动读 /sys 探测 EDL 9008，不调 edl-ng（避免抢 USB 会话；对齐 flange）。
detect_device() {
    local vid pid d
    for d in /sys/bus/usb/devices/*; do
        [ -r "$d/idVendor" ] && [ -r "$d/idProduct" ] || continue
        vid="$(cat "$d/idVendor" 2>/dev/null || true)"
        pid="$(cat "$d/idProduct" 2>/dev/null || true)"
        if [ "$vid" = "05c6" ] && [ "$pid" = "9008" ]; then return 0; fi
    done
    return 1
}

require_edl_mode() {
    _step "探测 EDL 设备 ($EDL_USB)"
    if detect_device; then
        _ok "已检测到 Qualcomm HS-USB QDLoader 9008"
    else
        _err "未检测到 EDL 设备 ($EDL_USB)。"
        _info "进入 EDL：断电 → 按住 EDL 按钮 → 用 USB3 线连接主机上电。"
        _info "确认 lsusb 中出现 '05c6:9008'。USB 访问受限时用 SUDO=sudo 重试。"
        exit 1
    fi
}

# ─────────────────────────── 刷写动作 ───────────────────────────
# edl-ng --loader <loader> --memory <mem> rawprogram <rawprogram*.xml> <patch*.xml>
# 在 <dir> 内执行，使 XML 中的相对 filename 能解析。
flash_rawprogram() {
    local edl="$1" mem="$2" dir="$3" loader="$4"
    [ -d "$dir" ] || die "镜像目录不存在: $dir"
    [ -f "$loader" ] || die "未找到 firehose loader: $loader"

    # 兼容 deploy 根目录或其 partition_ufs/ 子目录
    if [ ! -e "$dir/rawprogram0.xml" ] && [ -e "$dir/partition_ufs/rawprogram0.xml" ]; then
        dir="$dir/partition_ufs"; _info "使用子目录: ${dir#$REPO_DIR/}"
    fi

    local raws patches
    raws=$(cd "$dir" && ls -1 rawprogram*.xml 2>/dev/null | sort -V || true)
    patches=$(cd "$dir" && ls -1 patch*.xml 2>/dev/null | sort -V || true)
    [ -n "$raws" ] || die "在 $dir 未找到 rawprogram*.xml"

    _step "edl-ng rawprogram → $mem（loader: $(basename "$loader")）"
    _info "目录: $dir"
    _info "rawprogram: $(echo $raws | tr '\n' ' ')"
    _info "patch:      $(echo $patches | tr '\n' ' ')"

    ( cd "$dir" && $SUDO "$edl" --loader "$loader" --memory "$mem" \
        rawprogram $raws $patches ) \
        || die "edl-ng rawprogram 失败"
    _ok "$mem 刷写完成"
}

cmd_fetch() {
    _hdr "获取固件包"
    ensure_firmware
    _info "loader:   $(locate_loader)"
    _info "ufs_hlos: $(locate_ufs_dir)"
}

cmd_spinor() {
    local edl loader sdir; edl="$(ensure_edl_ng)"
    _hdr "刷写引导固件 (SPI NOR, bring-up) — $MACHINE"
    ensure_firmware
    loader="$(locate_loader)"
    sdir="$(dirname "$loader")"        # spinor 固件与 loader 同目录
    require_edl_mode
    flash_rawprogram "$edl" "spinor" "$sdir" "$loader"
}

cmd_ufs() {
    local edl loader dir; edl="$(ensure_edl_ng)"
    _hdr "刷写系统盘 (UFS HLOS) — $MACHINE"
    ensure_firmware
    loader="$(locate_loader)"
    dir="${UFS_DIR:-$(locate_ufs_dir)}"
    [ -n "$dir" ] || die "未定位到 UFS 镜像目录；可设 UFS_DIR 指向 deploy/images/$MACHINE"
    require_edl_mode
    flash_rawprogram "$edl" "UFS" "$dir" "$loader"
}

cmd_reset() {
    local edl; edl="$(ensure_edl_ng)"
    _step "edl-ng reset（复位并退出 EDL）"
    $SUDO "$edl" reset || _warn "reset 失败，请手动断电重启"
}

cmd_detect() {
    _hdr "EDL 设备探测"
    require_edl_mode
    _info "edl-ng: $(ensure_edl_ng)"
}

usage() {
    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}"
}

# ─────────────────────────── 入口 ───────────────────────────
main() {
    local cmd="${1:-}"
    case "$cmd" in
        detect) cmd_detect ;;
        fetch)  cmd_fetch ;;
        spinor) cmd_spinor ;;
        ufs)    cmd_ufs ;;
        all)    cmd_spinor; cmd_ufs; cmd_reset ;;
        reset)  cmd_reset ;;
        ""|-h|--help|help) usage ;;
        *) _err "未知命令: $cmd"; echo; usage; exit 2 ;;
    esac
}
main "$@"
