"""Replace the helper process with direct asynchronous QMI LOC preparation."""
from pathlib import Path
import difflib
import re

ws=Path('/mnt/c/postmarketOS-gta4l')
source=Path('/home/pmos/sm-t505-port/sources/modemmanager-gps-inspect/ModemManager-7f0bf17ab518cd78925cf7e53cc0d5c42f88b41a/src/mm-shared-qmi.c')
old=source.read_text()
function_start=old.index('static void\nstart_gps_engine (')
loc_branch=old.index('    /* Otherwise LOC */',function_start)
start=old.index('    if (client) {',loc_branch)
end=old.index('\n    g_task_return_new_error',start)
original=old[start:end]
assert original.count('qmi_client_loc_start (')==1
send_start='''static void
loc_send_start (QmiClientLoc *client, GTask *task)
{
    g_autoptr(QmiMessageLocStartInput) input = qmi_message_loc_start_input_new ();

    qmi_message_loc_start_input_set_session_id (input, DEFAULT_LOC_SESSION_ID, NULL);
    qmi_message_loc_start_input_set_intermediate_report_state (input, QMI_LOC_INTERMEDIATE_REPORT_STATE_DISABLE, NULL);
    qmi_message_loc_start_input_set_minimum_interval_between_position_reports (input, 1000, NULL);
    qmi_message_loc_start_input_set_fix_recurrence_type (input, QMI_LOC_FIX_RECURRENCE_TYPE_REQUEST_PERIODIC_FIXES, NULL);
    qmi_client_loc_start (client, input, 10, NULL,
                         (GAsyncReadyCallback) loc_start_ready, task);
}

'''
replacement='''    if (client) {
        if (g_strcmp0 (mm_base_modem_get_plugin (MM_BASE_MODEM (self)), "qcom-soc") == 0 &&
            g_strcmp0 (qmi_device_get_path_display (QMI_DEVICE (qmi_client_peek_device (client))), "qrtr://0") == 0 &&
            g_file_test ("/etc/ModemManager/gta4l-gps-unlock", G_FILE_TEST_IS_REGULAR)) {
            mm_obj_dbg (self, "Preparing SM-T505 GPS engine through QMI LOC");
            gta4l_loc_unlock (QMI_CLIENT_LOC (client), task);
        } else
            loc_send_start (QMI_CLIENT_LOC (client), task);
        return;
    }
'''
new=old[:start]+replacement+old[end:]
helpers=send_start+(ws/'port/modemmanager/gta4l-gps-unlock.c.inc').read_text()+'\n'
new=new.replace('static void\nstart_gps_engine (',helpers+'static void\nstart_gps_engine (',1)
# The earlier PDS branch and the LOC lookup must remain byte-for-byte intact.
assert old[function_start:start] in new
assert original.count('QMI_SERVICE_PDS')==0
patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/src/mm-shared-qmi.c',tofile='b/src/mm-shared-qmi.c'))
(ws/'port/modemmanager/gta4l-gps-request-unlock.patch').write_text(patch)
recipe=ws/'port/modemmanager/APKBUILD'
text=re.sub(r'^pkgrel=\d+$','pkgrel=3',recipe.read_text(),count=1,flags=re.M).replace('\tqmi-utils\n','')
recipe.write_text(text)
print('Prepared direct QMI LOC unlock with response/indication ordering and bounded timeout')
