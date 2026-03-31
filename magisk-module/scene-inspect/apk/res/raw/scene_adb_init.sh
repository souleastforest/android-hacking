scene="com.omarea.vtools"

SOURCE_DAMON="/storage/emulated/0/Android/data/$scene/daemon"
SOURCE_TOYBOX="/storage/emulated/0/Android/data/$scene/toolkit/toybox-outside64"
SOURCE_BUSYBOX="/storage/emulated/0/Android/data/$scene/toolkit/busybox"

STARTER_PATH="/data/local/tmp/scene-daemon"
TARGET_TOYBOX="/data/local/tmp/toolkit/toybox-outside"
TARGET_BUSYBOX="/data/local/tmp/toolkit/busybox"
toolkit="/data/local/tmp/toolkit"

mkdir $toolkit
# Env PATH add /data/local/tmp
export PATH=$PATH:$toolkit

cp $SOURCE_DAMON $STARTER_PATH
chmod 777 $STARTER_PATH
echo 'Success: Copy [scene-daemon] to complete'

cp $SOURCE_TOYBOX $TARGET_TOYBOX
chmod 777 $TARGET_TOYBOX
echo 'Success: Copy [toybox-outside] to complete'

cp $SOURCE_BUSYBOX $TARGET_BUSYBOX
chmod 777 $TARGET_BUSYBOX
echo 'Success: Copy [busybox] to complete'

echo 'Install BusyBox……'
cd $toolkit
for applet in `./busybox --list`; do
  case "$applet" in
  "sh"|"busybox"|"shell"|"swapon"|"swapoff"|"mkswap")
    echo '  Skip' > /dev/null
  ;;
  *)
    ./busybox ln -sf busybox "$applet";
  ;;
  esac
done
./busybox ln -sf busybox busybox_1_30_1

echo ''
nohup $STARTER_PATH >/dev/null 2>&1 &
if [[ $(pgrep scene-daemon) != "" ]]; then
  echo 'Scene-Daemon OK! ^_^'
else
  echo 'Scene-Daemon Fail! @_@'
fi

cmd package compile -m speed $scene >/dev/null 2>&1 &

dumpsys deviceidle whitelist +$scene >/dev/null 2>&1
cmd appops set $scene RUN_IN_BACKGROUND allow >/dev/null 2>&1
echo ''
