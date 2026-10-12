$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$evidenceDir = Join-Path $workspaceRoot 'evidence'
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$queries = [ordered]@{
    identity = 'getprop ro.product.model; getprop ro.product.device; getprop ro.bootloader; getprop ro.build.version.release; getprop ro.build.version.security_patch; uname -a; id'
    boot = 'cat /proc/cmdline; getprop ro.boot.verifiedbootstate; getprop ro.boot.flash.locked; getprop ro.boot.vbmeta.device_state; getprop ro.boot.warranty_bit'
    inputs = 'cat /proc/bus/input/devices; wm size; wm density'
    storage = 'ls -l /dev/block/by-name; cat /proc/partitions; mount'
    firmware = 'ls -l /vendor/firmware; ls -l /vendor/firmware_mnt/image; ls -l /vendor/etc/wifi; ls -l /vendor/etc/bluetooth'
    drivers = 'ls /sys/bus/platform/drivers; cat /proc/modules; ls /sys/class/net; ls /sys/class/sound; ls /sys/class/power_supply; cat /proc/asound/cards; cat /proc/asound/pcm'
    hardware = 'getprop ro.board.platform; getprop ro.hardware; getprop ro.hardware.egl; getprop ro.hardware.vulkan; ls /sys/class/graphics; ls /sys/class/backlight; ls /sys/class/leds; ls /sys/class/remoteproc'
}
foreach ($entry in $queries.GetEnumerator()) {
    $output = & adb shell $entry.Value 2>&1
    $output | Set-Content -LiteralPath (Join-Path $evidenceDir ($entry.Key + '.txt')) -Encoding utf8
    Write-Output ('Collected ' + $entry.Key)
}
