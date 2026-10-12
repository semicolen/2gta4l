# SM-T505 battery reporting audit — 12 October 2026

The growing time-to-full estimate is reproduced and explained by near-zero
net charging on the connected computer USB port. No incorrect capacity unit,
current sign or desktop percentage source was found in this check. No charging
limits, packages or boot image were changed.

## Measured behavior

The charger reports a 500 mA input limit at about 4.88 V. UPower detects the
connected `pc_port` correctly and reports `OnBattery=false`. During four short
samples, percentage stayed at 70%; time-to-full increased from 43.13 to 54.89
to 66.44 hours as the reported net charging power fell from 0.199 to 0.156 to
0.129 W. The fourth sample reported net discharge while USB remained connected.

The exact installed UPower 1.91.0 source was downloaded locally in WSL and
verified against the package's SHA512. Its formula divides remaining energy
by net charging power. Each charging estimate matches that formula to within
one second. Close to zero net power, modest load changes produce very large
time estimates; these are extrapolations rather than a measured charge time.

A controlled display test explicitly verified panel state for every sample:

| State | Median net battery current |
| --- | ---: |
| Screen on before | +34.8 mA |
| Screen off | +471.9 mA |
| Screen on again | +38.1 mA |

Positive current in the primary `battery` supply means net charge. The display
was restored on afterward. This short comparison demonstrates the effect of
tablet load on the available charging power; it does not measure a full cycle.

## Driver and policy checks

The vendor SMB5 charger deliberately uses the external CW2017 gauge for
percentage, voltage and temperature, while other values come from Qualcomm QG.
The primary battery and desktop both report the CW2017 percentage. The QG
auxiliary gauge reports a different percentage; it is not presented as another
desktop battery. The vendor driver negates QG current for the primary battery
interface. UPower deliberately reports discharging when that net current is
negative, even if the kernel charger status says charging.

Battery temperature measured 27.0–27.5 °C and the driver reported `Good` health.
Software temperature-dependent charging protection (`sw_jeita_enabled`) and
step charging were both enabled. The kernel's `CONFIG_DISABLE_TEMP_PROTECT`
bypass was disabled. Store mode and slate mode were both off. The existing
vendor profile and voltage/current limits were retained. Protection operation
under abnormal temperatures was not exercised.

UPower uses percentage for low-battery policy: low at 20%, critical at 5% and
action at 2%. The growing time estimate does not choose those thresholds.
The configured critical action is HybridSleep; its execution and system
suspend remain unverified.

The primary gauge reports 7,063 mAh for both full and design capacity, giving
a desktop capacity-health value of 100%. QG's driver falls back to nominal
capacity when learned-capacity feedback is not enabled; the active QG node
does not enable that feedback. Thus 100% is not evidence of an unworn battery.
The auxiliary CW2017 supply has a hard-coded `charge_full_design=4000`; UPower
ignores that BMS supply and uses the primary battery's capacity. That auxiliary
number was not used to change charging configuration.

## Remaining validation

Normal wall-charger negotiation and charging rate, full-charge termination,
long discharge/runtime, actual low-battery shutdown, physical battery wear
and suspend need separate tests. These observations explain the estimate;
they do not establish complete charging or thermal validation.

Evidence and hashes are recorded in `artifacts/battery-verification.json`.
The diagnostics are under `evidence/diagnostic-boot-20261009/`, with filenames
beginning `device-r21-battery-`. The earlier display baseline had already
idled off and is excluded from the controlled comparison above. An initial
inventory query blocked on Linux's wakeup counter; that diagnostic was stopped
and the blocking field removed before the successful inventory.

References: [UPower 1.91.0 source](https://gitlab.freedesktop.org/upower/upower/-/tree/v1.91.0),
[Linux power supply units](https://docs.kernel.org/power/power_supply_class.html)
and [UPower device properties](https://upower.freedesktop.org/docs/Device.html).
