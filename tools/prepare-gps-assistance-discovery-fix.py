#!/usr/bin/env python3
"""Retain an early LOC assistance indication until its command reply arrives."""
from pathlib import Path
import difflib,re

workspace=Path(__file__).resolve().parents[1]
base=Path('/home/ark/sm-t505-port')
path=base/'sources/modemmanager-gps-inspect/ModemManager-7f0bf17ab518cd78925cf7e53cc0d5c42f88b41a/src/mm-shared-qmi.c'
old=path.read_text();new=old
start=new.index('/* Location: load supported assistance data */')
end=new.index('/* Location: Inject UTC time */',start)
part=new[start:end]
assert part.count('    guint         timeout_id;')==1
part=part.replace('    guint         timeout_id;',
                  '    guint         timeout_id;\n    gboolean      response_received;\n'
                  '    gboolean      processed;\n    QmiIndicationLocGetPredictedOrbitsDataSourceOutput *indication;')
needle='    g_slice_free (LoadSupportedAssistanceDataContext, ctx);'
assert part.count(needle)==1
part=part.replace(needle,'    if (ctx->indication)\n'
                  '        qmi_indication_loc_get_predicted_orbits_data_source_output_unref (ctx->indication);\n'+needle)
new=new[:start]+part+new[end:]
name='loc_location_get_predicted_orbits_data_source_indication_cb'
assert new.count(name)==2
new=new.replace(name+' (QmiClientLoc',
                'loc_location_get_predicted_orbits_data_source_process_indication (QmiClientLoc',1)
marker='static void\nloc_location_get_predicted_orbits_data_source_ready ('
assert new.count(marker)==1
helpers='''/* Replies and indications may arrive in either order.  Keep the task owned
 * by the command callback until its acknowledgement has been validated. */
static void
loc_location_get_predicted_orbits_data_source_consume (GTask *task)
{
    LoadSupportedAssistanceDataContext *ctx = g_task_get_task_data (task);

    if (!ctx->response_received || !ctx->indication || ctx->processed)
        return;
    ctx->processed = TRUE;
    if (ctx->timeout_id) {
        g_source_remove (ctx->timeout_id);
        ctx->timeout_id = 0;
    }
    if (ctx->indication_id) {
        g_signal_handler_disconnect (ctx->client, ctx->indication_id);
        ctx->indication_id = 0;
    }
    loc_location_get_predicted_orbits_data_source_process_indication (ctx->client, ctx->indication, task);
}

static void
loc_location_get_predicted_orbits_data_source_indication_cb (QmiClientLoc *client,
                                                             QmiIndicationLocGetPredictedOrbitsDataSourceOutput *output,
                                                             GTask *task)
{
    LoadSupportedAssistanceDataContext *ctx = g_task_get_task_data (task);

    if (ctx->indication)
        return;
    ctx->indication = qmi_indication_loc_get_predicted_orbits_data_source_output_ref (output);
    loc_location_get_predicted_orbits_data_source_consume (task);
}

'''
new=new.replace(marker,helpers+marker)
start=new.index(marker)
end=new.index('\nvoid\nmm_shared_qmi_location_load_supported_assistance_data',start)
part=new[start:end]
begin=part.index('    /* The task ownership is shared between signal and timeout;')
finish=part.index('    qmi_message_loc_get_predicted_orbits_data_source_output_unref (output);',begin)
part=part[:begin]+'''    ctx->response_received = TRUE;
    if (!ctx->indication)
        ctx->timeout_id = g_timeout_add_seconds (10,
                                                 (GSourceFunc)loc_location_get_predicted_orbits_data_source_indication_timed_out,
                                                 task);

'''+part[finish:]
needle='    qmi_message_loc_get_predicted_orbits_data_source_output_unref (output);\n}'
assert part.count(needle)==1
part=part.replace(needle,'    qmi_message_loc_get_predicted_orbits_data_source_output_unref (output);\n'
                  '    loc_location_get_predicted_orbits_data_source_consume (task);\n}')
new=new[:start]+part+new[end:]
needle='    qmi_client_loc_get_predicted_orbits_data_source (ctx->client,'
assert new.count(needle)==1
new=new.replace(needle,'''    /* Subscribe before sending: this modem may indicate before acknowledging. */
    ctx->indication_id = g_signal_connect (ctx->client,
                                           "get-predicted-orbits-data-source",
                                           G_CALLBACK (loc_location_get_predicted_orbits_data_source_indication_cb),
                                           task);
'''+needle)
assert new.count('loc_location_get_predicted_orbits_data_source_indication_cb')==2
patch=('Retain LOC assistance discovery indications that arrive before the reply.\n'
       'Subscribe before sending and consume only after both results are available.\n'
       'Preserve existing timeout, error, server and injection-event handling.\n\n')
patch+=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
                                fromfile='a/src/mm-shared-qmi.c',tofile='b/src/mm-shared-qmi.c'))
package=workspace/'port/modemmanager'
(package/'loc-assistance-discovery-order.patch').write_text(patch,newline='\n')
recipe=package/'APKBUILD';text=recipe.read_text()
assert re.search(r'^pkgrel=(3|4)$',text,re.M)
text=re.sub(r'^pkgrel=3$','pkgrel=4',text,flags=re.M)
if '\tloc-assistance-discovery-order.patch\n' not in text:
    text=text.replace('\tgta4l-gps-request-unlock.patch\n','\tgta4l-gps-request-unlock.patch\n\tloc-assistance-discovery-order.patch\n')
recipe.write_text(text,newline='\n')
recipe=workspace/'port/gps-gta4l/APKBUILD';text=recipe.read_text()
assert re.search(r'^pkgrel=(3|4)$',text,re.M)
text=re.sub(r'^pkgrel=3$','pkgrel=4',text,flags=re.M)
text=text.replace('modemmanager=1.25.95_git20261005-r3','modemmanager=1.25.95_git20261005-r4')
recipe.write_text(text,newline='\n')
print('GPS_ASSISTANCE_DISCOVERY_ORDER_FIX_PREPARED')
