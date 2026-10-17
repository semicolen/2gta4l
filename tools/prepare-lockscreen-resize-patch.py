"""Keep the locker and keyboard allocations synchronized with monitor changes."""
from pathlib import Path
import difflib

root = Path(__file__).resolve().parents[1]
upstream = Path('/home/ark/sm-t505-port/sources/lockscreen-inspect')
source = upstream/'xfce4-screensaver-4.20.2'
package = root/'port/xfce4-screensaver'
package.mkdir(exist_ok=True)
recipe = (upstream/'APKBUILD').read_text().replace('pkgrel=0', 'pkgrel=1')
recipe = recipe.replace('\tpam-base-auth.patch\n', '\tpam-base-auth.patch\n\tmonitor-resize.patch\n')
(package/'APKBUILD').write_text(recipe, newline='\n')
(package/'pam-base-auth.patch').write_bytes((upstream/'pam-base-auth.patch').read_bytes())

changes = {}
name = 'src/gs-lock-plug.c'
original = (source/name).read_text()
marker = 'static void\nkeyboard_toggled_cb ('
handler = '''/* Monitor rotation changes both the background's minimum size and the
 * XEmbed plug's fixed size request. Keep the existing authentication dialog. */
static void
lock_monitor_geometry_notify (GdkMonitor *monitor,
                              GParamSpec *pspec,
                              GSLockPlug *plug) {
    GdkRectangle geometry;
    gdk_monitor_get_geometry (monitor, &geometry);
    redraw_background (plug);
    gtk_widget_set_size_request (plug->priv->plug_widget,
                                 geometry.width, geometry.height);
    gtk_widget_queue_resize (plug->priv->plug_widget);
}

'''
assert original.count(marker) == 1
changed = original.replace(marker, handler + marker)
marker = '    gtk_window_set_focus_on_map (GTK_WINDOW (plug->priv->plug_widget), TRUE);'
connection = '''    GdkDisplay *display = gdk_display_get_default ();
    GdkMonitor *monitor = gdk_display_get_monitor (display, monitor_index);
    if (monitor == NULL)
        monitor = gdk_display_get_monitor (display, 0);
    if (monitor != NULL)
        g_signal_connect_object (monitor, "notify::geometry",
                                 G_CALLBACK (lock_monitor_geometry_notify), plug, 0);

'''
assert changed.count(marker) == 1
changes[name] = (original, changed.replace(marker, connection + marker))

name = 'src/gs-window.c'
original = (source/name).read_text()
marker = '''    gs_debug ("Got monitor geometry notify signal");
    gtk_widget_queue_resize (GTK_WIDGET (window));'''
replacement = '''    gs_debug ("Got monitor geometry notify signal");
    if (window->priv->keyboard_socket != NULL) {
        GdkRectangle geometry;
        gint height;
        gdk_monitor_get_geometry (monitor, &geometry);
        height = geometry.height < 610 ? 205 - ((610 - geometry.height) / 2) : 205;
        gtk_widget_set_size_request (window->priv->keyboard_socket,
                                     MIN (geometry.width, 1400), MAX (height, 1));
    }
    gtk_widget_queue_resize (GTK_WIDGET (window));'''
assert original.count(marker) == 1
changes[name] = (original, original.replace(marker, replacement))
patch = ''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                    fromfile='a/'+name, tofile='b/'+name))
                for name, (before, after) in changes.items())
(package/'monitor-resize.patch').write_text(patch, newline='\n')
print('Prepared monitor resize handlers; authentication and lock state unchanged')
