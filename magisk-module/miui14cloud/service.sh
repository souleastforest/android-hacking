# !/system/bin/sh
# 请不要硬编码 /magisk/modname/... ; 请使用 $MODDIR/...
# 这将使你的脚本更加兼容，即使Magisk在未来改变了它的挂载点
MODDIR=${0%/*}
alias sh='/system/bin/sh'
# 这个脚本将以 late_start service 模式执行
# 更多信息请访问 Magisk 主题
lock_value() {
    if [ -f "$1" ]; then
        chown root:root "$1"
        chmod 0666 "$1"
        echo "$2" >"$1"
        chmod 0444 "$1"
    fi
}

restart_mi_thermald(){
    ALLMODIR=/data/adb/modules
    ALLUPMODIR=/data/adb/modules_update
    for i in $(find $ALLMODIR -name mi_thermald);do
        rm $i
    done
    for i in $(find $ALLUPMODIR -name mi_thermald);do
        rm $i
    done
    mi_alive=$(ps -ef| grep mi_thermald | grep -v grep)
    [ "$mi_alive" == "" ] && nohup /vendor/bin/mi_thermald 2>&1 &
}

wait_until_login() {
    # in case of /data encryption is disabled
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 1
    done
    # no need to start before the user unlocks the screen
    local test_file="/sdcard/Android/.LOGIN_PERMISSION_TEST"
    true > "$test_file"
    while [ ! -f "$test_file" ]; do
        true > "$test_file"
        sleep 1
    done
    rm "$test_file"
}

# Wait
wait_until_login
sh $MODDIR/Restore.sh > /dev/null 2>&1
sleep 60s

# Extra
sh $MODDIR/Extra.sh > /dev/null 2>&1

# Flash rate
sh $MODDIR/Flashrate.sh > /dev/null 2>&1

# Fuck mcd
rm -rf /data/system/mcd
mkdir /data/system/mcd
chmod 444 /data/system/mcd
chattr +i /data/system/mcd

# Mi_thermald
restart_mi_thermald

# Pangufix
cp -r /product/pangu/system/* $MODDIR/system/product/