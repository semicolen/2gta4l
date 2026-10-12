#!/usr/bin/env python3
"""Restore SSPP programming when a DPMS-preserved plane becomes active."""
from pathlib import Path
import difflib

workspace = Path(__file__).resolve().parents[1]
relative = 'techpack/display/msm/sde/sde_plane.c'
original = (Path('/home/pmos/sm-t505-port/kernel') / relative).read_text()
old = '''\t/* force reprogramming of all the parameters, if the flag is set */
\tif (psde->revalidate) {
'''
new = '''\t/*
\t * DPMS keeps the plane framebuffer and rectangles unchanged, but
\t * disabling the CRTC loses SSPP programming. The CRTC unregisters
\t * its power-event callback before power-down, so POST_DISABLE may
\t * not set revalidate. Restore all plane state on the active edge.
\t */
\tif (psde->revalidate || crtc->state->active_changed) {
'''
assert original.count(old) == 1
updated = original.replace(old, new, 1)
patch = ''.join(difflib.unified_diff(
    original.splitlines(True), updated.splitlines(True),
    fromfile='a/' + relative, tofile='b/' + relative))
(workspace / 'port/linux-samsung-gta4l/plane-resume-state.patch').write_text(patch, newline='\n')
print('Generated SSPP active-transition revalidation patch')
