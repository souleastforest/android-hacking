set_value() {
  if [[ -f $2 ]]; then
    echo $1 > $2
  fi
}
set_value 10 /sys/class/meizu/charger/wired_level
set_value 10 /sys/class/meizu/wireless/wls_level

set_value 10 /sys/class/meizu/charger/wired/wired_level
set_value 10 /sys/class/meizu/wireless/wired/wls_level

stop thermal-engine
# killall vendor.meizu.hardware.meizu_charging@1.0-service
