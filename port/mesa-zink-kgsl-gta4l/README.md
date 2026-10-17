# Isolated SM-T505 Zink runtime

This is the tested Plasma Desktop OpenGL runtime for the downstream KGSL kernel. Mesa
26.0.8 is used for Zink because Mesa 26.2.4 requires maintenance5, which the
installed Turnip Adreno 610 device does not expose. The existing isolated
Turnip Vulkan package stays at 26.2.4.

The patch permits explicit KGSL device selection without matching the display
DRM node to a Vulkan DRM device. The wrapper forces the single KGSL ICD and
selects this private EGL, GL, GLES, Gallium and GBM runtime. Normal driver
selection remains unchanged outside the explicitly selected GPU session.

Run a diagnostic or application with `gta4l-zink-run COMMAND [ARGS...]`.
The Plasma Desktop installer selects the wrapper in its session descriptor and
clears inherited software flags in its session environment. The SDDM greeter
and an explicit Plasma fallback retain software rendering. Rendering, buffer
sharing, native presentation and actual accelerated KWin composition pass on
the tablet after reboot, with physical wake/input/rotation/camera checks.
Results and limitations are recorded in GPU-REPORT.md.

Build locally in WSL Ubuntu with `tools/build-zink-kgsl-package.sh`.
The APK uses pmbootstrap's cross-native2 workflow, with native Python/Meson
tools and ARM64 target dependencies. Alpine's `ldpath` setting traces the
private libraries without installing files over the system graphics stack.
