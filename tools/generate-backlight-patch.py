#!/usr/bin/env python3
"""Fix the confirmed downstream DCS write result and optional GPIO default."""
from pathlib import Path
import difflib

workspace = Path(__file__).resolve().parents[1]
relative = 'techpack/display/msm/dsi/dsi_panel.c'
source = Path('/home/ark/sm-t505-port/kernel') / relative
original = source.read_text()
old = '''\trc = mipi_dsi_dcs_set_display_brightness(dsi, bl_lvl);

\tif (rc < 0)
\t\tDSI_ERR("failed to update dcs backlight:%d\\n", bl_lvl);

\treturn rc;
'''
new = '''\trc = mipi_dsi_dcs_set_display_brightness(dsi, bl_lvl);

\tif (rc < 0) {
\t\tDSI_ERR("failed to update dcs backlight:%d\\n", bl_lvl);
\t\treturn rc;
\t}

\t/* Backlight callbacks return zero on success, not a DCS byte count. */
\treturn 0;
'''
assert original.count(old) == 1
updated = original.replace(old, new)
marker = '/* liuchunyang.wt add 2021 11 27\n\tpanel->reset_config.vcc = utils->get_named_gpio'
assert updated.count(marker) == 1
updated = updated.replace(marker,
    '''/* Optional VCC GPIO must be invalid when absent, rather than GPIO zero. */
\tpanel->reset_config.vcc = utils->get_named_gpio(utils->data,
\t\t\t\t\t"qcom,platform-vcc-gpio", 0);
''' + marker)
patch = ''.join(difflib.unified_diff(original.splitlines(True), updated.splitlines(True),
    fromfile='a/' + relative, tofile='b/' + relative))
(workspace / 'port/linux-samsung-gta4l/backlight-status.patch').write_text(patch, newline='\n')
print('Generated bounded DCS status and optional VCC GPIO patch')
