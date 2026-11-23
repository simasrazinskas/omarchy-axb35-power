#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
tool="$here/bin/axb35-power"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export AXB35_SYSFS="$work/sys" AXB35_STATE="$work/state/mode" AXB35_CPUFREQ="$work/cpufreq"

mkdir -p "$AXB35_SYSFS/apu" "$AXB35_SYSFS/temp1"
echo performance >"$AXB35_SYSFS/apu/power_mode"
echo 41 >"$AXB35_SYSFS/temp1/temp"
for fan in fan1 fan2 fan3; do
  mkdir -p "$AXB35_SYSFS/$fan"
  for f in mode rampup_curve rampdown_curve; do echo x >"$AXB35_SYSFS/$fan/$f"; done
  echo 1758 >"$AXB35_SYSFS/$fan/rpm"
done

for policy in policy0 policy1; do
  mkdir -p "$AXB35_CPUFREQ/$policy"
  echo 5187500 >"$AXB35_CPUFREQ/$policy/cpuinfo_max_freq"
  echo 5187500 >"$AXB35_CPUFREQ/$policy/scaling_max_freq"
done

fail=0
check() {
  actual=$(cat "$AXB35_SYSFS/$1" 2>/dev/null || cat "$1")
  if [ "$actual" != "$2" ]; then
    echo "FAIL $3: $1 = $actual, want $2"
    fail=1
  fi
}

while read -r mode cpu_up cpu_down sys_up sys_down cpu_max; do
  "$tool" "$mode"
  check "$AXB35_CPUFREQ/policy0/scaling_max_freq" "$cpu_max" "$mode: every core capped at 4 GHz"
  check "$AXB35_CPUFREQ/policy1/scaling_max_freq" "$cpu_max" "$mode: every policy capped"
  check apu/power_mode "$mode" "$mode"
  check fan1/rampup_curve "$cpu_up" "$mode"
  check fan2/rampdown_curve "$cpu_down" "$mode"
  check fan3/rampup_curve "$sys_up" "$mode"
  check fan3/rampdown_curve "$sys_down" "$mode"
  check fan1/mode curve "$mode"
  check fan3/mode curve "$mode"
  check "$AXB35_STATE" "$mode" "$mode saved"
done <<EOF
quiet 50,58,66,74,82 45,53,61,69,77 45,55,63,71,80 40,50,58,66,75 4000000
balanced 50,60,70,78,88 45,55,65,73,83 45,55,65,75,85 40,50,60,70,80 4000000
performance 45,55,65,75,85 40,50,60,70,80 40,50,60,70,80 35,45,55,65,75 4000000
EOF

echo 3000000 >"$AXB35_CPUFREQ/policy1/cpuinfo_max_freq"
"$tool" quiet
check "$AXB35_CPUFREQ/policy1/scaling_max_freq" 3000000 "the cap never raises a core above its own maximum"
echo 5187500 >"$AXB35_CPUFREQ/policy1/cpuinfo_max_freq"

"$tool" quiet
echo performance >"$AXB35_SYSFS/apu/power_mode"
"$tool" apply
check apu/power_mode quiet "apply restores the saved mode"

echo bogus >"$AXB35_STATE"
"$tool" apply
check apu/power_mode performance "apply falls back to performance on a bad state file"

rm "$AXB35_STATE"
"$tool" apply
check apu/power_mode performance "apply defaults to performance with no state file"

out=$("$tool" status)
want=$(printf 'power=performance\nsaved=performance\ntemp=41\nfan1=1758\nfan2=1758\nfan3=1758\ncpu_max_khz=4000000')
[ "$out" = "$want" ] || {
  echo "FAIL status: $out"
  fail=1
}

before=$(cat "$AXB35_SYSFS/apu/power_mode")
if "$tool" turbo 2>/dev/null; then
  echo "FAIL unknown mode accepted"
  fail=1
fi
check apu/power_mode "$before" "unknown mode leaves the EC alone"

if "$tool" quiet extra 2>/dev/null; then
  echo "FAIL extra argument accepted"
  fail=1
fi

[ $fail -eq 0 ] && echo "ok"
exit $fail
