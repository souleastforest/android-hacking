level="$1" # 清理级别（0:极微, 1：轻微，2：更重，3：极端）

# Messages
kernel_unsupported="@string:home_shell_01"
swap_too_low="@string:home_shell_02"
prohibit_parallel="@string:home_shell_03"
reclaim_completed="@string:home_shell_04"
calculation_error="@string:home_shell_05"
memory_enough="@string:home_shell_06"
write_back_completed="@string:home_shell_05"

# 级别0用在实时加速中，一般处于内存负载较高的状态下，此时缓存占用本就不高，无需再清理
if [[ "$level" != "0" ]]; then
  echo 3 > /proc/sys/vm/drop_caches
fi

modify_path='none'
friendly=false
use_memcg=false

if [[ -e /sys/fs/cgroup/memory/memory.swappiness ]]; then
  scene_memcg="/sys/fs/cgroup/memory"
elif [[ -d /dev/memcg ]]; then
  scene_memcg="/dev/memcg"
fi

if [[ -f '/proc/sys/vm/extra_free_kbytes' ]]; then
  modify_path='/proc/sys/vm/extra_free_kbytes'
  friendly=true
elif [[ -d $scene_memcg ]]; then
  use_memcg=true
elif [[ -f '/proc/sys/vm/min_free_kbytes' ]]; then
  modify_path='/proc/sys/vm/min_free_kbytes'
else
  echo $kernel_unsupported
  return 1
fi

min_free_kbytes=$(cat $modify_path)

MemTotalStr=`cat /proc/meminfo | grep MemTotal`
MemTotal=${MemTotalStr:16:8}

MemMemFreeStr=`cat /proc/meminfo | grep MemFree`
MemMemFree=${MemMemFreeStr:16:8}

SwapFreeStr=`cat /proc/meminfo | grep SwapFree`
SwapFree=${SwapFreeStr:16:8}

if [[ "$level" == "3" ]]; then
  if [[ $friendly == "true" ]]; then
    TargetRecycle=$(($MemTotal / 100 * 55))
  else
    TargetRecycle=$(($MemTotal / 100 * 26))
  fi
elif [[ "$level" == "2" ]]; then
  if [[ $friendly == "true" ]]; then
    TargetRecycle=$(($MemTotal / 100 * 35))
  else
    TargetRecycle=$(($MemTotal / 100 * 18))
  fi
elif [[ "$level" == "0" ]]; then
  if [[ $friendly == "true" ]]; then
    TargetRecycle=$(($MemTotal / 100 * 14))
  else
    TargetRecycle=$(($MemTotal / 100 * 10))
  fi
else
  if [[ $friendly == "true" ]]; then
    TargetRecycle=$(($MemTotal / 100 * 20))
  else
    TargetRecycle=$(($MemTotal / 100 * 12))
  fi
fi

zram_writback() {
  if [[ ! -f /sys/block/zram0/backing_dev ]] || [[ $(cat /proc/swaps | grep zram0) == '' ]]; then
    return 0
  fi
  backing_dev=$(cat /sys/block/zram0/backing_dev)
  echo 0 > /sys/block/zram0/writeback_limit_enable
  if [[ "$backing_dev" != '' ]] && [[ "$backing_dev" != 'none' ]]; then
    # echo [all | ?seconds] > /sys/block/zram0/idle
    # echo all > /sys/block/zram0/idle
    # echo [idle | huge_idle | incompressible] > /sys/block/zram0/writeback
    # echo idle > /sys/block/zram0/writeback

    for d in 1800 600 300 all; do
      echo $d > /sys/block/zram0/idle
      for t in incompressible huge_idle idle; do
        echo $t > /sys/block/zram0/writeback
        MemMemFree=${MemMemFreeStr:16:8}
        if [[ $MemMemFree -gt $TargetRecycle ]]; then
          return 1
        fi
      done
    done
  fi
  return 0
}

apps_memcg(){
  if [[ $(getprop ro.build.version.sdk) -lt 28 ]]; then
    return
  fi
  if [[ ! -d $scene_memcg ]]; then
    return
  fi

  mkdir -p $scene_memcg/apps
  mkdir -p $scene_memcg/system
  cat $scene_memcg/memory.swappiness > $scene_memcg/apps/memory.swappiness
  cat $scene_memcg/memory.swappiness > $scene_memcg/system/memory.swappiness

  for set in '' '/apps' '/system';do
    echo 1 > $scene_memcg$set/memory.use_hierarchy
    echo 1 > $scene_memcg$set/memory.oom_control
    echo 1 > $scene_memcg$set/memory.move_charge_at_immigrate
  done

  dumpsys activity lru | grep '#' | while read line; do
    for col in $line;do
      if [[ $col == */* ]]; then
        pid=$(echo $col | awk -F ':' '{print $1}')
        uid=$(echo $col | awk -F '/' '{print $2}')
        if [[ $uid == *i* ]]; then
          uid=$(echo $uid | awk -F 'i' '{print $1}')
        fi
        # Only set for user apps and not in cgroup
        if [[ $(grep memory /proc/$pid/cgroup | awk -F '/' '{print $2}') == '' ]]; then
          # echo $pid $uid
          if [[ $uid == u* ]]; then
            echo $pid > $scene_memcg/apps/cgroup.procs
          else
            echo $pid > $scene_memcg/system/cgroup.procs
          fi
        fi
      fi
    done
  done
}

memcg_reclaim() {
  # 太暴力啦，会卡到怀疑人生
  # echo "echo 1 > $scene_memcg/apps/memory.force_empty" > /cache/force_empty.sh

  cmd=""

  # 先回收scene创建的垃圾堆
  for set in scene_idle; do
    if [[ -e $scene_memcg/$set ]]; then
      limit=$(cat $scene_memcg/$set/memory.soft_limit_in_bytes)
      if [[ $limit == '9223372036854771712' ]]; then
        limit='384M'
      fi
      cmd="$cmd\necho $limit > $scene_memcg/$set/memory.limit_in_bytes"
    fi
  done

  # 然后回收apps
  for set in apps; do
    if [[ -e $scene_memcg/$set ]]; then
      usage=$(cat $scene_memcg/$set/memory.usage_in_bytes)
      limit_kb=$((usage/1000-$TargetRecycle))
      # 避免压到 < 384MB
      if [[ $limit_kb -lt 393216 ]]; then
        limit_kb=393216
      fi
      cmd="$cmd\necho ${limit_kb}K > $scene_memcg/$set/memory.limit_in_bytes"
    fi
  done

  # 最后system也压榨一点
  for set in scene_active system; do
    if [[ -e $scene_memcg/$set ]]; then
      usage=$(cat $scene_memcg/$set/memory.usage_in_bytes)
      in_swap=$(grep '^swap' "$scene_memcg/$set/memory.stat" | awk '{print $2}')
      total_sys=$((usage+in_swap))
      limit_kb=$((usage*50/100/1000)) # system应用期望其内存swap率为50%
      # 避免压到 < 384MB
      if [[ $limit_kb -lt 393216 ]]; then
        limit_kb=393216
      fi
      cmd="$cmd\necho ${limit_kb}K > $scene_memcg/$set/memory.limit_in_bytes"
    fi
  done

  echo "$cmd" > /cache/force_empty.sh
  nohup sh /cache/force_empty.sh > /dev/null &
}

memcg_reclaim_stop() {
  killall 'sh /cache/force_empty.sh'
  rm -f '/cache/force_empty.sh' 2>/dev/null
  for set in apps system scene_active scene_idle; do
    if [[ -e $scene_memcg/$set ]]; then
      echo '9223372036854771712' > $scene_memcg/$set/memory.limit_in_bytes
    fi
  done
}

force_reclaim() {
  # 计算需要回收多少内存
  RecyclingSize=$(($TargetRecycle - $MemMemFree))

  # 计算回收这些内存需要消耗的SWAP容量
  SwapRequire=$(($RecyclingSize / 100 * 130))

  # 如果没有足够的Swap容量可以回收这些内存
  # 则只拿Swap剩余容量的50%来回收内存
  if [[ $SwapFree -lt $SwapRequire ]]; then
    # 模式0优先保证性能，SWAP不足时强制回收有风险，因此不执行
    if [[ "$level" == "0" ]]; then
      echo $swap_too_low
      return 5
    fi
    RecyclingSize=$(($SwapFree / 100 * 50))
  fi

  # 最后计算出最终要回收的内存大小
  TargetRecycle=$(($RecyclingSize + $MemMemFree))

  if [[ $RecyclingSize != "" ]] && [[ $RecyclingSize -gt 0 ]]; then
    # 状态记录，避免同时执行多次
    setprop vtools.state.force_compact 1

    if [[ $use_memcg == "true" ]]; then
      apps_memcg
      memcg_reclaim $TargetRecycle
    else
      echo $TargetRecycle > $modify_path
    fi

    # 回收超时时间(秒)
    duration_limit=30
    # 级别0用在实时加速中，最重要的保持系统的持续流畅，隐藏缩短回收持续时间，减少卡顿
    if [[ "$level" == "0" ]]; then
      reclaim_timeout=$(($RecyclingSize / 1024 / 120 + 2))
      duration_limit=6
    else
      # echo Scene App $(($RecyclingSize / 1024))MB >> /cache/force_compact.log
      reclaim_timeout=$(($RecyclingSize / 1024 / 60 + 2))
    fi
    if [[ $reclaim_timeout -gt $duration_limit ]]; then
      reclaim_timeout=$duration_limit
    fi

    while [[ $reclaim_timeout -gt 0 ]]; do
      sleep 1
      MemMemFreeStr=`cat /proc/meminfo | grep MemFree`
      MemMemFree=${MemMemFreeStr:16:8}

      # 如果内存已经回收足够，提前结束
      if [[ $(($TargetRecycle - $MemMemFree)) -lt 100 ]]; then
        break
      fi

      # 如果memcg回收脚本已退出，提前结束
      if [[ $use_memcg == "true" ]] && [[ $(pidof -x 'force_empty.sh') == '' ]]; then
        break
      fi

      SwapFreeStr=`cat /proc/meminfo | grep SwapFree`
      SwapFree=${SwapFreeStr:16:8}
      # 如果SWAP可用空间已经不足，提前结束
      if [[ $SwapFree -lt 100 ]]; then
        break
      fi

      # 否则继续等待倒计时结束
      reclaim_timeout=$((reclaim_timeout-1))
    done

    # 还原原始设置
    if [[ $use_memcg == "true" ]]; then
      memcg_reclaim_stop
    else
      echo $min_free_kbytes > $modify_path
    fi
    echo $reclaim_completed

    # 清除执行状态标记
    setprop vtools.state.force_compact 0
  else
    echo $calculation_error
  fi
}

# 状态记录，避免同时执行多次
if [[ $(getprop vtools.state.force_compact) == "1" ]]; then
  echo $prohibit_parallel
  return 0
fi

# 如果可用内存大于目标可用内存大小，则不需要回收了
if [[ $MemMemFree -gt $TargetRecycle ]]; then
  echo $memory_enough
else
  zram_writback

  if [[ "$?" == '1' ]]; then
    echo $write_back_completed
  else
    force_reclaim
  fi
fi

if [[ -f /proc/sys/vm/compact_memory ]]; then
  echo 1 > /proc/sys/vm/compact_memory
fi
