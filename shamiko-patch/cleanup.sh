if [ -f /data/adb/modules/zygisk_shamiko/disable ]; then
  # shellcheck disable=SC2016
  sed -i 's/^description=.*/description=これで勝ったと思うなよ―――!!/' /data/adb/modules/zygisk_shamiko/module.prop
  rm /data/adb/post-fs-data.d/.shamiko_cleanup.sh
fi
