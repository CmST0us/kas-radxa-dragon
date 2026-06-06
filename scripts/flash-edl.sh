#!/usr/bin/env bash
#
# flash-edl.sh — 用 edl-ng 在 EDL 模式下刷写 Radxa Dragon Q6A (QCS6490) 固件
#
# 参考 flange 的 builder/flash.py:QualcommFlashStrategy，适配本 kas/Yocto 工程。
#
# 固件包：SPI NOR 引导固件与 firehose loader 取自 Radxa 官方 **LE/QCLINUX** flat_build：
#   https://dl.radxa.com/dragon/q6a/images/dragon-q6a_flat_build_251013.zip
# ⚠ 必须用 LE(Linux) 套件，**切勿用 wp_*(Windows Platform) 套件**——WP 的 SPI 引导固件
#   （HYP 为 Windows 用 hyp.mbn、UEFI 出 ACPI/SMBIOS 而非设备树）与本仓库构建的 Qualcomm
#   Linux HLOS 不配套，会让内核早期静默挂死、热复位入 dload（即「全量刷 UFS 仍不启动」的真因，
#   因为 UFS 刷写不碰 SPI NOR）。详见 wiki/topics/flashing.md。
# 首次运行会自动下载并解压到 scripts/firmware/（已 gitignore）。脚本只引用工程内路径，
# 不依赖本机任何外部路径。
#
# 两类刷写目标：
#   - spinor : 引导固件（XBL/EDK2 等 SPI NOR），来自固件包的 spinor 目录。
#   - ufs    : 系统盘 = kas 自构建镜像 deploy/images/<machine>/qcom-multimedia-image，
#              默认刷全部 LUN0-5（efi+system+全套引导固件）。该目录会自动定位，无需手填；
#              也可用 UFS_DIR 显式指定。
#
# LUN 刷写形态（实测）：把列表内所有 rawprogram<N>.xml + patch<N>.xml 在**一次** edl-ng
#   调用里传完（先全部 rawprogram，再全部 patch）即可写完 LUN0-5（含 xbl/aop/dtb/tz/… 引导
#   固件）——edl-ng 与 qdl 均已真机验证。逐 LUN 分开调用才会让 LUN1-5 被 NAK（曾误判为「设备
#   只接受 LUN0」，根因实为调用形态）。只想更新 OS 时设 UFS_LUNS=0。详见 wiki/topics/flashing.md。
#
# 速度：本板经 USB2（480Mbps）枚举时 ~34MiB/s，system.img(~8.8GB) 约需 270s。换 USB3
#   口/线可显著提速。MAXPAYLOAD 不影响 USB2 吞吐（瓶颈在链路）。
#
# 进入 EDL 模式：断电 → 按住 EDL 按钮 → 用 USB 线连接主机上电
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

# 要刷写的 UFS physical_partition（LUN）列表。默认刷全部 LUN0-5（efi+system+全套引导固件）。
# 形态对齐实测成功的 qdl：把列表内所有 rawprogram<N>.xml + patch<N>.xml **一次性合并**传给
# edl-ng（而非逐 LUN 分开调用——后者在本板上对 LUN1-5 会 NAK）。只想更新 OS 时设 UFS_LUNS=0。
UFS_LUNS="${UFS_LUNS:-0 1 2 3 4 5}"

# Firehose 单包负载（字节）。注意：本板经 USB2（480Mbps）枚举时吞吐恒为 ~34MiB/s，
# 加大此值并不会提速（USB 链路才是瓶颈，换 USB3 口/线可显著提速）。保留此旋钮仅为
# 兼容个别 loader；默认 1MB。若某 loader 不支持大包导致 configure 失败，调小。
MAXPAYLOAD="${MAXPAYLOAD:-1048576}"

# 官方固件包与工程内缓存目录（一切外部资源下载进工程，不引用工程外路径）。
# 只在刷 spinor 引导固件时用到，放在 scripts/ 下（不污染仓库根）。
# ⚠ 必须是 LE/QCLINUX flat_build（不是 wp_* 的 Windows 套件）——理由见文件头与 wiki。
FW_URL="${FW_URL:-https://dl.radxa.com/dragon/q6a/images/dragon-q6a_flat_build_251013.zip}"
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
# edl-ng --loader <loader> --memory <mem> rawprogram <rawprogram…> <patch…>
# 在 <dir> 内执行，使 XML 中的相对 filename 能解析。
# flash_rawprogram <edl> <mem> <dir> <loader> <luns>
#   <luns> = 要刷的 physical_partition 号列表（空格分隔），如 "0" 或 "0 1 2 3 4 5"。
#
# 把列表内**所有** rawprogram<N>.xml + patch<N>.xml 在**一次** edl-ng 调用里传完（先列全部
# rawprogram，再列全部 patch），而非逐 LUN 分开调用。已真机实测：合并调用下 edl-ng 与 qdl 均
# 可一次写完 LUN0-5（含引导固件）；逐 LUN 分开调用才会让 LUN1-5 被 NAK（曾误判为「设备只接受
# LUN0」）。根因是调用形态，与工具无关。
# 只取标准 rawprogram<N>.xml / patch<N>.xml，绝不匹配 *_BLANK_GPT / *_WIPE_PARTITIONS（破坏性）。
flash_rawprogram() {
    local edl="$1" mem="$2" dir="$3" loader="$4" luns="$5"
    [ -d "$dir" ] || die "镜像目录不存在: $dir"
    [ -f "$loader" ] || die "未找到 firehose loader: $loader"

    # 兼容 deploy 根目录或其 partition_ufs/ 子目录
    if [ ! -e "$dir/rawprogram0.xml" ] && [ -e "$dir/partition_ufs/rawprogram0.xml" ]; then
        dir="$dir/partition_ufs"; _info "使用子目录: ${dir#$REPO_DIR/}"
    fi

    # 收集存在的 rawprogram / patch：先全部 rawprogram，再全部 patch（对齐 qdl 成功形态）。
    local n raws=() patches=()
    for n in $luns; do
        [ -e "$dir/rawprogram$n.xml" ] || { _warn "LUN $n: 无 rawprogram$n.xml，跳过"; continue; }
        raws+=("rawprogram$n.xml")
        [ -e "$dir/patch$n.xml" ] && patches+=("patch$n.xml")
    done
    [ ${#raws[@]} -gt 0 ] || die "目录内无任何 rawprogram<N>.xml: $dir"

    _step "edl-ng rawprogram → $mem（loader: $(basename "$loader")，LUN: $luns，payload ${MAXPAYLOAD}B）"
    _info "目录: $dir"
    _info "rawprogram: ${raws[*]}"
    _info "patch: ${patches[*]:-（无）}"

    # 单次合并调用：rawprogram0 rawprogram1 … patch0 patch1 …
    if ( cd "$dir" && $SUDO "$edl" --loader "$loader" --memory "$mem" \
            --maxpayload "$MAXPAYLOAD" rawprogram \
            "${raws[@]}" ${patches[@]+"${patches[@]}"} ); then
        _ok "$mem 刷写完成（LUN: $luns）"
    else
        die "$mem 刷写失败（LUN: $luns）。只想刷 OS 时用 UFS_LUNS=0 重试；若 LUN1-5 仍 NAK 见 wiki/topics/flashing.md"
    fi
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
    # 安全网：WP(Windows) 套件的 SPI 引导固件与本仓库 Linux HLOS 不配套，刷了会无法启动。
    # 即便 FW_URL 已默认 LE 包，scripts/firmware/ 里若残留旧的 WP 解压物也会在此被拦下。
    if ls "$sdir"/devcfg_windows_hyp* "$sdir"/PILFV.Fv "$sdir"/hyp.mbn >/dev/null 2>&1; then
        _err "检测到 WP(Windows) 引导固件特征（PILFV.Fv / devcfg_windows_hyp* / hyp.mbn）于：${sdir#$REPO_DIR/}"
        _err "本仓库构建的是 Qualcomm Linux(LE/QCLINUX) HLOS，必须刷 LE 套件的 spinor（含 hypvm.mbn/独立 uefi.elf）。"
        _info "清掉缓存重取正确包： rm -rf \"$FW_DIR\" && $0 fetch  （FW_URL 已默认 LE flat_build）"
        die "拒绝刷入 WP 引导固件（防止把设备刷成无法启动）。详见 wiki/topics/flashing.md。"
    fi
    require_edl_mode
    # edl-ng 的 --memory 枚举为大写：NAND|NVME|SDCC|SPINOR|UFS。SPI NOR 只有单个 LUN0。
    flash_rawprogram "$edl" "SPINOR" "$sdir" "$loader" "0"
}

# kas 自构建系统镜像目录：build/.../deploy/images/<machine>/qcom-multimedia-image
# 该目录是自洽的整套刷写集（system.img/efi.bin/dtb.bin + rawprogram<N>.xml + 同目录 loader）。
# 注意：deploy 根目录虽也有 rawprogram<N>.xml，却缺重命名后的 system.img/efi.bin/dtb.bin，
# 故必须用 qcom-multimedia-image 子目录。
locate_build_ufs_dir() {
    local d="$REPO_DIR/build/tmp-glibc/deploy/images/$MACHINE/qcom-multimedia-image"
    if [ -f "$d/rawprogram0.xml" ]; then echo "$d"; return; fi
    # 退路：在 build 下搜任意 qcom-multimedia-image（machine/构建目录名有差异时）
    find "$REPO_DIR/build" -type d -name qcom-multimedia-image \
        -exec test -f '{}/rawprogram0.xml' ';' -print -quit 2>/dev/null
}

cmd_ufs() {
    local edl loader dir; edl="$(ensure_edl_ng)"
    _hdr "刷写系统盘 (UFS HLOS) — $MACHINE"
    # 目录定位优先级：UFS_DIR 显式 → kas 自构建 qcom-multimedia-image → 固件包内 ufs_hlos
    dir="${UFS_DIR:-}"
    [ -n "$dir" ] || dir="$(locate_build_ufs_dir)"
    if [ -z "$dir" ]; then ensure_firmware; dir="$(locate_ufs_dir)"; fi
    [ -n "$dir" ] || die "未定位到 UFS 镜像目录；可设 UFS_DIR 指向 deploy/images/$MACHINE/qcom-multimedia-image"

    # loader 优先用镜像目录内同版本的 prog_firehose_ddr.elf；缺失才回落到固件包。
    if [ -f "$dir/prog_firehose_ddr.elf" ]; then
        loader="$dir/prog_firehose_ddr.elf"
    else
        ensure_firmware; loader="$(locate_loader)"
    fi
    require_edl_mode
    # 默认 UFS_LUNS="0 1 2 3 4 5"：合并一次调用刷全部 LUN（efi+system+全套引导固件）。
    # 只想更新 OS、保留设备原引导固件时设 UFS_LUNS=0（见 flash_rawprogram 注释与
    # wiki/topics/flashing.md）。
    flash_rawprogram "$edl" "UFS" "$dir" "$loader" "$UFS_LUNS"
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
