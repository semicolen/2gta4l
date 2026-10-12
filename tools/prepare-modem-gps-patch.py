"""Apply a device-selected asynchronous GPS unlock immediately before LOC start."""
from pathlib import Path
import difflib

ws=Path('/mnt/c/postmarketOS-gta4l')
source=Path('/home/pmos/sm-t505-port/sources/modemmanager-gps-inspect/ModemManager-7f0bf17ab518cd78925cf7e53cc0d5c42f88b41a/src/mm-shared-qmi.c')
old=source.read_text()
block='''        QmiMessageLocStartInput *input;

        input = qmi_message_loc_start_input_new ();
        qmi_message_loc_start_input_set_session_id (input, DEFAULT_LOC_SESSION_ID, NULL);
        qmi_message_loc_start_input_set_intermediate_report_state (input, QMI_LOC_INTERMEDIATE_REPORT_STATE_DISABLE, NULL);
        qmi_message_loc_start_input_set_minimum_interval_between_position_reports (input, 1000, NULL);
        qmi_message_loc_start_input_set_fix_recurrence_type (input, QMI_LOC_FIX_RECURRENCE_TYPE_REQUEST_PERIODIC_FIXES, NULL);
        qmi_client_loc_start (QMI_CLIENT_LOC (client),
                              input,
                              10,
                              NULL,
                              (GAsyncReadyCallback) loc_start_ready,
                              task);
        qmi_message_loc_start_input_unref (input);
        return;'''
assert old.count(block)==1
helpers='''/* Downstream SM-T505: the modem may reapply its lock after boot. The device
 * package opts in to unlocking only when a location client requests GPS. The
 * existing qmicli operation waits for the asynchronous LOC completion event;
 * run it asynchronously so the ModemManager main loop remains responsive. */
static void
loc_send_start (QmiClientLoc *client, GTask *task)
{
    QmiMessageLocStartInput *input;

    input = qmi_message_loc_start_input_new ();
    qmi_message_loc_start_input_set_session_id (input, DEFAULT_LOC_SESSION_ID, NULL);
    qmi_message_loc_start_input_set_intermediate_report_state (input, QMI_LOC_INTERMEDIATE_REPORT_STATE_DISABLE, NULL);
    qmi_message_loc_start_input_set_minimum_interval_between_position_reports (input, 1000, NULL);
    qmi_message_loc_start_input_set_fix_recurrence_type (input, QMI_LOC_FIX_RECURRENCE_TYPE_REQUEST_PERIODIC_FIXES, NULL);
    qmi_client_loc_start (client, input, 10, NULL,
                         (GAsyncReadyCallback) loc_start_ready, task);
    qmi_message_loc_start_input_unref (input);
}

static void
gta4l_gps_unlock_ready (GSubprocess *process, GAsyncResult *res, GTask *task)
{
    g_autoptr(GError) error = NULL;

    if (!g_subprocess_wait_check_finish (process, res, &error)) {
        g_prefix_error (&error, "Couldn't prepare SM-T505 GPS engine: ");
        g_task_return_error (task, g_steal_pointer (&error));
        g_object_unref (task);
        return;
    }
    loc_send_start (QMI_CLIENT_LOC (g_task_get_task_data (task)), task);
}

'''
needle='static void\nstart_gps_engine (MMSharedQmi'
assert old.count(needle)==1
new=old.replace(needle,helpers+needle)
replacement='''        if (g_strcmp0 (mm_base_modem_get_plugin (MM_BASE_MODEM (self)), "qcom-soc") == 0 &&
            g_strcmp0 (qmi_device_get_path_display (QMI_DEVICE (qmi_client_peek_device (client))), "qrtr://0") == 0 &&
            g_file_test ("/etc/ModemManager/gta4l-gps-unlock", G_FILE_TEST_IS_REGULAR)) {
            g_autoptr(GSubprocess) process = NULL;
            g_autoptr(GError) error = NULL;

            process = g_subprocess_new (G_SUBPROCESS_FLAGS_STDOUT_SILENCE | G_SUBPROCESS_FLAGS_STDERR_SILENCE,
                                        &error, "/usr/bin/qmicli", "-d", "qrtr://0",
                                        "--loc-set-engine-lock=none", NULL);
            if (!process) {
                g_task_return_error (task, g_steal_pointer (&error));
                g_object_unref (task);
                return;
            }
            mm_obj_dbg (self, "Preparing SM-T505 GPS engine before LOC start");
            g_task_set_task_data (task, g_object_ref (client), g_object_unref);
            g_subprocess_wait_check_async (process, NULL,
                                           (GAsyncReadyCallback) gta4l_gps_unlock_ready, task);
            return;
        }
        loc_send_start (QMI_CLIENT_LOC (client), task);
        return;'''
new=new.replace(block,replacement)
patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/src/mm-shared-qmi.c',tofile='b/src/mm-shared-qmi.c'))
(ws/'port/modemmanager/gta4l-gps-request-unlock.patch').write_text(patch)
recipe=ws/'port/modemmanager/APKBUILD'
text=recipe.read_text()
if '\tqmi-utils\n' not in text:
    text=text.replace('\tdbus\n','\tdbus\n\tqmi-utils\n',1)
# abuild verifies each source against checksums in source order. Keep the new
# source last, matching the local checksum entry appended by configure-port.
text=text.replace('\tgta4l-gps-request-unlock.patch\n','')
text=text.replace('\t0001-intel-XMM7360-fix-big-endian-handling-of-ASN-integer.patch\n','\t0001-intel-XMM7360-fix-big-endian-handling-of-ASN-integer.patch\n\tgta4l-gps-request-unlock.patch\n',1)
# This source builds its own libmm-glib. The upstream bootstrap dependency on
# an already published identical split package cannot resolve our new release.
text=text.replace('makedepends="\n\t$depends_dev\n','makedepends="\n')
recipe.write_text(text)
print('Prepared GPS request quirk selected by device marker, qcom-soc and QRTR node 0')
