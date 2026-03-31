if [[ -f /sys/devices/soc0/machine ]]; then
  echo 1
else
  echo 0
fi