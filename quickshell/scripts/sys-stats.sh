#!/usr/bin/env bash
# Emit one JSON line of CPU/GPU stats for the control center.
set -euo pipefail

cpu_temp=$(sensors -j 2>/dev/null | jq -r '
  [.. | objects | ."Package id 0"?.temp1_input // empty][0]
  // [.. | objects | .Tctl?.temp1_input // empty][0]
  // [.. | objects | .temp1?.temp1_input // empty][0]
  // "null"
' 2>/dev/null || echo null)

# Fallback: coretemp via sensors text
if [[ "$cpu_temp" == "null" || -z "$cpu_temp" ]]; then
  cpu_temp=$(sensors 2>/dev/null | awk '/Package id 0:/{gsub(/\+|°C/,"",$4); print $4; exit}')
  [[ -n "${cpu_temp:-}" ]] || cpu_temp=null
fi

# CPU usage over a short sample
read -r u1 t1 < <(awk '/^cpu /{print $2+$4, $2+$4+$5; exit}' /proc/stat)
sleep 0.25
read -r u2 t2 < <(awk '/^cpu /{print $2+$4, $2+$4+$5; exit}' /proc/stat)
cpu_usage=$(awk -v u1="$u1" -v t1="$t1" -v u2="$u2" -v t2="$t2" 'BEGIN{
  dt=t2-t1; if(dt<=0){print 0}else{printf "%.0f", (u2-u1)*100/dt}
}')

cpu_cores=$(nproc 2>/dev/null || echo 0)
mem_used=$(free -b | awk '/^Mem:/{printf "%.0f", $3/1024/1024}')
mem_total=$(free -b | awk '/^Mem:/{printf "%.0f", $2/1024/1024}')
mem_pct=$(free | awk '/^Mem:/{printf "%.0f", $3*100/$2}')

gpu_temp=null
gpu_usage=null
gpu_mem_used=null
gpu_mem_total=null
gpu_name=""

if command -v nvidia-smi >/dev/null 2>&1; then
  IFS=',' read -r gpu_temp gpu_usage gpu_mem_used gpu_mem_total gpu_name < <(
    nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,name \
      --format=csv,noheader,nounits 2>/dev/null | head -n1 | sed 's/, /,/g'
  )
  gpu_temp=${gpu_temp:-null}
  gpu_usage=${gpu_usage:-null}
  gpu_mem_used=${gpu_mem_used:-null}
  gpu_mem_total=${gpu_mem_total:-null}
  gpu_name=${gpu_name:-""}
fi

jq -nc \
  --argjson cpu_temp "${cpu_temp:-null}" \
  --argjson cpu_usage "${cpu_usage:-0}" \
  --argjson cpu_cores "${cpu_cores:-0}" \
  --argjson mem_used "${mem_used:-0}" \
  --argjson mem_total "${mem_total:-0}" \
  --argjson mem_pct "${mem_pct:-0}" \
  --argjson gpu_temp "${gpu_temp:-null}" \
  --argjson gpu_usage "${gpu_usage:-null}" \
  --argjson gpu_mem_used "${gpu_mem_used:-null}" \
  --argjson gpu_mem_total "${gpu_mem_total:-null}" \
  --arg gpu_name "$gpu_name" \
  '{
    cpuTemp: $cpu_temp,
    cpuUsage: $cpu_usage,
    cpuCores: $cpu_cores,
    memUsed: $mem_used,
    memTotal: $mem_total,
    memPct: $mem_pct,
    gpuTemp: $gpu_temp,
    gpuUsage: $gpu_usage,
    gpuMemUsed: $gpu_mem_used,
    gpuMemTotal: $gpu_mem_total,
    gpuName: $gpu_name
  }'
