# Desktop profiles

`profiles.json` describes six isolated image builds. Rendering environment files
are applied only to Wayland images. The Sxmo output file supplies the physical
panel baseline; its compositor behavior still needs a tablet test.

`aports/postmarketos-ui-plasma-{mobile,desktop}` contains the corresponding
upstream pmaports recipes and source files captured from revision
`8b13cfdbea31aee694a3e7266c7a531189db33f0`. Original authors and package licenses
are retained. Each recipe's release is increased by one and
`pmb:support-openrc` is added to its options. Both recipes already contain
OpenRC subpackages and login-service hooks; upstream metadata otherwise selects
the systemd channel despite an OpenRC user preference.

`tools/build-ui-profiles.sh` places these overlays in the local pmaports `main/`
tree and builds both packages using pmbootstrap. They are downstream candidates;
declaring the packaging option does not establish runtime support for a native
Wayland desktop. GNOME and Sxmo already advertise OpenRC support and use their
unmodified local pmaports profiles.
