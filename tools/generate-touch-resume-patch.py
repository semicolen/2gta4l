#!/usr/bin/env python3
"""Order the TDDI firmware reload before the LCD on-command sequence."""
from pathlib import Path
import difflib

workspace = Path(__file__).resolve().parents[1]
relative = 'drivers/input/touchscreen/hxchipset/himax_platform.c'
original = (Path('/home/pmos/sm-t505-port/kernel') / relative).read_text()
start = original.index('int drm_notifier_callback(')
old = '''#ifdef HX_CONTAINER_SPEED_UP
\t\t\tqueue_delayed_work(ts->ts_int_workqueue,
\t\t\t\t&ts->ts_int_work,
\t\t\t\tmsecs_to_jiffies(0));
#else
'''
new = '''#ifdef HX_CONTAINER_SPEED_UP
\t\t\t/*
\t\t\t * The panel's id 29 notification occurs after its GPIO
\t\t\t * reset and before DSI on commands. A deferred firmware
\t\t\t * reload resets this shared TDDI chip after LCD setup.
\t\t\t * Finish that reload here while the LCD is still off.
\t\t\t */
\t\t\tif (evdata->id == 29) {
\t\t\t\tcancel_delayed_work_sync(&ts->ts_int_work);
\t\t\t\tpr_info("[HXTP] synchronous pre-LCD firmware resume start\\n");
\t\t\t\tif (!ts->initialized && himax_chip_common_init())
\t\t\t\t\treturn -ECANCELED;
\t\t\t\thimax_chip_common_resume(ts);
\t\t\t\tpr_info("[HXTP] synchronous pre-LCD firmware resume complete\\n");
\t\t\t} else {
\t\t\t\tqueue_delayed_work(ts->ts_int_workqueue,
\t\t\t\t\t&ts->ts_int_work,
\t\t\t\t\tmsecs_to_jiffies(0));
\t\t\t}
#else
'''
assert original[start:].count(old) == 1
updated = original[:start] + original[start:].replace(old, new, 1)
patch = ''.join(difflib.unified_diff(original.splitlines(True), updated.splitlines(True),
    fromfile='a/' + relative, tofile='b/' + relative))
(workspace / 'port/linux-samsung-gta4l/touch-resume-order.patch').write_text(patch, newline='\n')
print('Generated synchronous pre-LCD TDDI resume patch')
