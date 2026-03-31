status=`dumpsys battery | grep status`
if [[ $(echo $status | grep 2) != "" ]]; then
  echo 'Charging, timer skipped!'
  exit 0
fi