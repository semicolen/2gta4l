#!/usr/bin/env python3
"""Repair reentrant SSC discovery/claim ordering in SensorProxy 3.9."""
from pathlib import Path
import difflib,re
workspace=Path(__file__).resolve().parents[1]
source=Path('/home/ark/sm-t505-port/diagnostics/sensor-proxy-source/iio-sensor-proxy-3.9/src/iio-sensor-proxy.c')
old=source.read_text();new=old
needle='\tfor (guint i = 0; i < NUM_SENSOR_TYPES; i++)\n\t\tdata->clients[i] = create_clients_hash_table ();'
assert new.count(needle)==1
new=new.replace(needle,'''\tfor (guint i = 0; i < NUM_SENSOR_TYPES; i++) {
\t\tdata->clients[i] = create_clients_hash_table ();
\t\tdata->sensor_startup_dbus_invocations_delayed[i] = g_ptr_array_new ();
\t}''')
needle='\n\t\tdata->sensor_startup_dbus_invocations_delayed[i] = g_ptr_array_new ();\n\n\t\tif (!driver_type_exists (data, i))'
assert new.count(needle)==1
new=new.replace(needle,'\n\t\tif (!driver_type_exists (data, i))')
# A synchronous SSC discovery/open dispatches the main loop. Claims can arrive
# after a driver is selected but before its SensorDevice has been published.
start=new.index('static void\nhandle_generic_method_call ')
end=new.index('\nstatic void\nhandle_method_call ',start)
function=new[start:end]
assert function.count('if (driver_type_exists (data, driver_type))')==1
function=function.replace('if (driver_type_exists (data, driver_type))',
    'if (driver_type_exists (data, driver_type) && DEVICE_FOR_TYPE(driver_type) != NULL)')
new=new[:start]+function+new[end:]
needle='\tif (driver_type_exists (data, driver_type) &&\n\t    g_hash_table_size (ht) == 0)'
assert new.count(needle)==1
new=new.replace(needle,'\tif (driver_type_exists (data, driver_type) &&\n\t    DEVICE_FOR_TYPE(driver_type) != NULL &&\n\t    g_hash_table_size (ht) == 0)')
needle='\t\tDEVICE_FOR_TYPE(i) = sensor_device;\n\t}\n\n\tif (!any_sensors_left (data))'
assert new.count(needle)==1
new=new.replace(needle,'''\t\tDEVICE_FOR_TYPE(i) = sensor_device;

\t\t/* SSC discovery/open may dispatch claims before the device is ready.
\t\t * Honor those clients as we do when a claimed sensor is hotplugged. */
\t\tif (g_hash_table_size (data->clients[i]) > 0) {
\t\t\tdata->sensor_startup_dbus_event_delayed[i] = TRUE;
\t\t\tdriver_set_polling (sensor_device, TRUE);
\t\t}
\t}

\tif (!any_sensors_left (data))''')
patch='''Honor sensor claims received while synchronous SSC discovery dispatches D-Bus.
Initialize deferred invocations before discovery, avoid polling an unpublished
device, and start sampling for clients already present when initial open ends.

'''+''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
                               fromfile='a/src/iio-sensor-proxy.c',tofile='b/src/iio-sensor-proxy.c'))
package=workspace/'port/iio-sensor-proxy'
(package/'ssc-early-claim.patch').write_text(patch,newline='\n')
recipe=package/'APKBUILD';text=recipe.read_text()
assert re.search(r'^pkgrel=[34]$',text,re.M)
text=re.sub(r'^pkgrel=3$', 'pkgrel=4',text,flags=re.M)
if '\tssc-early-claim.patch\n' not in text:
    text=text.replace('\tdownstream-fastrpc-discovery.patch\n','\tdownstream-fastrpc-discovery.patch\n\tssc-early-claim.patch\n')
recipe.write_text(text,newline='\n')
print('SENSOR_PROXY_EARLY_CLAIM_SOURCE_PREPARED',flush=True)
