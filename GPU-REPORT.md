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
Normal desktop OpenGL still reports llvmpipe software rendering.

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

This verifies hardware Vulkan computation and a bounded graphics test.
It does not establish accelerated desktop OpenGL, complete Vulkan
conformance, system suspend, long idle stability, or compatibility with arbitrary apps.
