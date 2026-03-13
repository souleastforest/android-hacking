#!/system/bin/sh
# service.sh - SMS OTP AutoFill KernelSU daemon
# 职责：持续监听新短信 → 正则提取 OTP → 写入 FIFO → Companion App 读取后自动填入
# by souleastforest

OTP_FIFO="/data/local/tmp/sms_otp.fifo"
OTP_LOG="/data/local/tmp/sms-otp-service.log"
POLL_INTERVAL=2          # 轮询间隔（秒）
COMPANION_PKG="com.souleastforest.smsotp"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$OTP_LOG"
}

# ── 正则提取 OTP（覆盖主流格式）─────────────────────────────────
# 示例：「您的验证码是 123456」「OTP: 4567」「code is 789012」
extract_otp() {
    local body="$1"
    # 优先匹配「验证码/code/OTP」前后的 4~8 位数字
    OTP=$(echo "$body" | grep -oE '(\b|\D)([0-9]{4,8})(\b|\D)' \
        | grep -oE '[0-9]{4,8}' | head -1)
    echo "$OTP"
}

# ── 确保 FIFO 存在 ────────────────────────────────────────────
ensure_fifo() {
    if [ ! -p "$OTP_FIFO" ]; then
        rm -f "$OTP_FIFO"
        mkfifo "$OTP_FIFO"
        chmod 666 "$OTP_FIFO"
        log "Created FIFO: $OTP_FIFO"
    fi
}

# ── 等待 PackageManager 就绪 ─────────────────────────────────
log "=== SMS OTP service.sh started ==="
for i in $(seq 1 30); do
    PM_COUNT=$(pm list packages 2>/dev/null | wc -l)
    [ "$PM_COUNT" -gt 10 ] && { log "PM ready ($PM_COUNT packages)"; break; }
    log "Waiting PM... ($i/30)"
    sleep 3
done

ensure_fifo

# ── 等待 Companion App 启动 ──────────────────────────────────
for i in $(seq 1 20); do
    if pm list packages 2>/dev/null | grep -q "$COMPANION_PKG"; then
        log "Companion App found, starting accessibility service..."
        # 启动 Companion App（让其在后台注册 AccessibilityService）
        am start -n "$COMPANION_PKG/.MainActivity" \
            --activity-clear-top 2>/dev/null
        break
    fi
    log "Waiting for Companion App... ($i/20)"
    sleep 3
done

# ── 记录上一次处理的短信时间戳（用于增量检测）────────────────
LAST_TS=0
# 取当前最新短信时间戳作为起始基线，避免重放历史短信
INIT_TS=$(content query --uri content://sms/inbox \
    --projection date --sort "date DESC" --limit 1 2>/dev/null \
    | grep -oP 'date=\K[0-9]+' | head -1)
[ -n "$INIT_TS" ] && LAST_TS=$INIT_TS
log "Baseline SMS timestamp: $LAST_TS"

log "Watchdog started (${POLL_INTERVAL}s interval)"

# ── 主循环 ───────────────────────────────────────────────────
while true; do
    sleep $POLL_INTERVAL

    # 查询比 LAST_TS 更新的收件箱短信
    NEW_SMS=$(content query \
        --uri content://sms/inbox \
        --projection "_id,address,body,date" \
        --where "date > $LAST_TS" \
        --sort "date ASC" 2>/dev/null)

    if [ -z "$NEW_SMS" ]; then
        continue
    fi

    # 逐条处理新短信
    echo "$NEW_SMS" | while read -r LINE; do
        # 解析 date
        ROW_TS=$(echo "$LINE" | grep -oP 'date=\K[0-9]+')
        [ -z "$ROW_TS" ] && continue
        [ "$ROW_TS" -le "$LAST_TS" ] && continue

        BODY=$(echo "$LINE" | grep -oP 'body=\K.*')
        ADDR=$(echo "$LINE" | grep -oP 'address=\K[^,]+')

        OTP=$(extract_otp "$BODY")
        if [ -n "$OTP" ]; then
            log "New SMS from $ADDR | OTP=$OTP | body: ${BODY:0:60}"
            # 写入 FIFO（非阻塞：若无读端则丢弃，避免死锁）
            # 用子 shell + timeout 写，超时丢弃
            (echo "$OTP" > "$OTP_FIFO") &
            WRITE_PID=$!
            sleep 1
            kill -0 "$WRITE_PID" 2>/dev/null && kill "$WRITE_PID" 2>/dev/null
        fi

        # 更新游标
        LAST_TS=$ROW_TS
    done

    # 同步 LAST_TS（while 子 shell 无法反向修改父变量，这里重新查询最新值）
    LATEST_TS=$(content query \
        --uri content://sms/inbox \
        --projection date --sort "date DESC" --limit 1 2>/dev/null \
        | grep -oP 'date=\K[0-9]+' | head -1)
    [ -n "$LATEST_TS" ] && [ "$LATEST_TS" -gt "$LAST_TS" ] && LAST_TS=$LATEST_TS

done
