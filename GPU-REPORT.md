# SM-T505 GPU verification

The locally built Mesa 26.2.4 Turnip KGSL driver runs on the tablet's
Adreno 610. An ARM64 Vulkan compute test verified all 4096 GPU results as
both root and the normal `tablet` user. Vulkan reports an integrated Adreno
GPU, Mesa Turnip, and physical-device API version **1.0.354**. The loader's
instance version 1.4.360 is not the GPU's API version.

The locally built Vulkan Tools cube rendered and presented 300 frames with
exit status zero. The current Xorg configuration has no DRI3, so this test
uses `MESA_VK_WSI_DEBUG=sw` for CPU copying of the GPU-rendered frames to X11.
The selected rendering device remains Turnip Adreno 610. After the display
plane resume repair in kernel #8, the user confirmed a rotating cube visible
on the Xfce desktop. Root and normal-user compute tests also pass on #8.
The Xfce desktop configuration still uses llvmpipe software rendering.

Plasma Desktop QC on 2026-10-14 verifies hardware-accelerated KWin composition
after a normal reboot. KWin reports OpenGL ES 3.2 Mesa 26.0.8 and the renderer
`zink Vulkan 1.0(Turnip Adreno (TM) 610 (MESA_TURNIP))`. The user confirmed the
desktop opens with smooth rotation transitions and identifies the Adreno GPU.
Display off/on, all four orientations, touch and the on-screen keyboard pass.
Both cameras also pass colors, orientation, photo saving and preview restart
on the accelerated desktop. Normal-user Vulkan computation still verifies
all 4096 results. This result applies to Plasma Desktop; the other UI profiles
have not been converted or verified with this compositor setup.

On GNOME Desktop QC on 2026-10-15, the isolated runtime also passes the normal-user
Vulkan computation test, GLES shader/readback, linear display-buffer export/import
and a native Wayland presentation test. A GNOME user-session trial selects the
same wrapper, while GDM retains software rendering and a software session remains
available. After a clean reboot, the actual GNOME Shell process maps the private
Mesa 26.0.8 EGL/Gallium/GBM and Turnip libraries, holds the Adreno KGSL device
open and has no LLVM library mapped. The user confirms correct rotation, input,
display wake and both custom-camera regressions on this accelerated session.
The refreshed r12 clean-installer workflow carries this setup into GNOME Desktop
and a GNOME Mobile candidate; Mobile's actual compositor remains unverified.

The system Zink driver initially rejects the downstream display DRM node because
the KGSL Vulkan device cannot match that node through Vulkan DRM properties.
An isolated Mesa candidate adds an explicit KGSL-only device-selection option,
selected together with the exact Turnip ICD. It does not alter reported Vulkan
capabilities. Mesa 26.2.4 then encounters another limitation: its Zink requires
`VK_KHR_maintenance5`, which this GPU does not expose. Mesa 26.0.8 keeps that
extension optional, so the verified package uses a complete private EGL/GL/GBM
runtime under `/usr/lib/gta4l-zink`, selected only by `gta4l-zink-run`.

The compatible source archive matches the SHA256 and SHA512 in
[Mesa's 26.0.8 release notes](https://docs.mesa3d.org/relnotes/26.0.8.html).
Both driver builds and all ARM64 diagnostics are built locally in WSL Ubuntu.
The compatible Zink runtime reports OpenGL 4.0 and OpenGL ES 3.2 on Turnip
Adreno 610. A normal-user GLES test passed 120 shader frames and 240 pixel
checks. A linear 512×512 GBM buffer was exported, imported by the downstream
display render node, and mapped back with the correct red pixel value. Opening
a second primary DRM fd initially failed authentication while KWin held the
display master; the render node avoids that unrelated authentication issue.

Native Vulkan Wayland swapchain presentation exits with SIGBUS during
`eglMakeCurrent`. Selecting `LIBGL_KOPPER_DISABLE=true` uses Mesa's DRI image
presentation path instead. That path presented 2316 GPU-rendered native
Wayland frames over a minute, and the user confirmed a correctly colored,
rotating green triangle. A software-copy Vulkan WSI test also succeeds, but
the selected wrapper uses the DRI image path. No Vulkan capability is spoofed.
Package 26.0.8-r3 contains this selection and installs only the private runtime
and explicit application wrapper; existing graphics package versions remain
unchanged. The Plasma session descriptor selects this wrapper, and its session
environment clears the inherited software-rendering flags. The SDDM greeter
retains software rendering, and a separate Plasma software fallback remains
available at login. The r10 build recipe carries the tested session setup into
the clean installer. The rebuilt r10 image has now installed successfully through
OrangeFox, with matching boot readback, unchanged recovery and USB SSH after
first boot. Its active KWin renderer again identifies Zink/Turnip Adreno 610.
Fresh-install QC found lines and incorrect colors during rotation animations
at larger display scales; the user confirms clean animations at 100%. Kernel
logs show no new GPU faults, and a full-panel/odd-size RGBA8/RGBA16F texture
sampling regression passes. The cause remains unresolved; these results do not
assign the fault to KWin or Mesa. On 2026-10-15 the user deferred this issue to
continue GNOME Desktop and GNOME Mobile testing. Arbitrary scaling is not yet
a passed Plasma QC result.

Passing these tests establishes bounded application rendering, buffer sharing,
presentation and accelerated Plasma composition. It does not establish complete
OpenGL/Vulkan conformance, arbitrary application compatibility or long-duration
stability. Kernel logs show no new GPU faults during these tests and the
accelerated reboot regression.

Fresh GNOME r12 also exposed native Vulkan presentation failures in GTK 4 apps:
Settings and Calculator exited with SIGBUS. The GNOME user-session wrapper now
selects `GSK_RENDERER=gl`, retaining hardware OpenGL through private Zink/Turnip.
It explicitly sets the accelerated software flag to false so D-Bus activation
does not retain the greeter's inherited CPU-rendering setting. After a normal
reboot the user confirms Settings, Files, Calculator and Terminal open normally;
the compositor still maps the private drivers and holds the Adreno device.
This live fix is included in the r13 source recipe, awaiting image assembly.
Native GTK Vulkan presentation remains unresolved. GTK documents its renderer
selection in [Running GTK Applications](https://docs.gtk.org/gtk4/running.html).
The subsequent 16 October log collection also found a KGSL GPU fault attributed
to Firefox ESR 140.14.0-r0. The user recalls Firefox working. It was no longer
running when inspected, so its rendering path and any user-visible failure
were not established. The logged fault remains to investigate; the compositor
and GTK app checks do not establish browser stability. The private capture is
`evidence/ui-qc/gnome/20261016-app-fix/firefox-gpu-state.txt`.

Additional desktop accounts need the hardware groups used by the image's
default account. A newly created GNOME account had only its primary group and
wheel, and could not read or write either KGSL or ION. After the user's approval,
adding the default account's hardware groups makes both access checks pass;
the user confirms the new account's desktop and apps open. See USER-ACCOUNTS.md.

The driver is installed separately and selected explicitly:

```sh
VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json \
MESA_VK_WSI_DEBUG=sw vkcube --wsi xlib --c 300
```

Udev rules grant the `video` group access to `/dev/kgsl-3d0` and `/dev/ion`;
the tests run without root permissions. Both the Mesa driver and Vulkan
Tools were built locally in WSL Ubuntu. Their APKs and hashes are under
`artifacts/apks/` and `artifacts/SHA256SUMS`.

Evidence is saved in `evidence/diagnostic-boot-20261009/`:

- `kgsl-gpu-compute-root.raw`: root computation and readback.
- `kgsl-gpu-compute-user-ion.raw`: normal-user computation and readback.
- `kgsl-vulkan-summary-user.raw`: hardware device and API identification.
- `kgsl-vkcube-x11-copy.raw`: 300-frame graphics test, exit status zero.
- `kgsl-vkcube-user.raw`: initial failure without the X11 copy workaround.
- `kernel8-gpu-compute-root.raw` and `kernel8-gpu-compute-user.raw`: kernel #8 regression.
- `kernel8-vkcube-visible-start.raw`: normal-user graphics, physically confirmed.

Plasma evidence is saved locally in
`evidence/ui-qc/plasma-desktop/20261013T181627Z/`: `gpu-compositor-trial.txt`
records KWin's active renderer; `gpu-zink26-probes.txt` records shader readback;
`gpu-zink26-gbm-render-node.txt` records buffer sharing;
`gpu-zink26-wayland-visible.log` records native presentation; and
`gpu-plasma-wake-test.txt` and `gpu-camera-final-state.txt` record regressions.
Camera close leaves no capture helper or temporary frames. System suspend,
long idle stability and arbitrary application compatibility remain unverified.
