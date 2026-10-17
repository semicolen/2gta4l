#!/usr/bin/env python3
"""Handle QMI LOC injection indications before or after each chunk reply."""
from pathlib import Path
import difflib,re
workspace=Path(__file__).resolve().parents[1]
base=Path('/home/ark/sm-t505-port/sources/modemmanager-gps-inspect/ModemManager-7f0bf17ab518cd78925cf7e53cc0d5c42f88b41a/src/mm-shared-qmi.c')
old=base.read_text();new=old
start=new.index('/* Location: inject assistance data */')
end=new.index('\nvoid\nmm_shared_qmi_location_inject_assistance_data (',start)
part=new[start:end]
part=part.replace('    gulong        n_part;','    gulong        n_part;\n'
    '    gboolean      response_received;\n    gboolean      indication_received;\n'
    '    GError       *indication_error;\n    void        (*next_part) (GTask *task);')
part=part.replace('    g_free (ctx->data);','    g_clear_error (&ctx->indication_error);\n    g_free (ctx->data);')
marker='static void inject_xtra_data_next (GTask *task);'
helpers='''/* The command callback retains the task until its reply is validated.
 * An early indication only caches its result; it cannot advance the transfer. */
static void
loc_injection_clear_wait (InjectAssistanceDataContext *ctx)
{
    if (ctx->timeout_id) {
        g_source_remove (ctx->timeout_id);
        ctx->timeout_id = 0;
    }
    if (ctx->indication_id) {
        g_signal_handler_disconnect (ctx->client, ctx->indication_id);
        ctx->indication_id = 0;
    }
}

static void
loc_injection_consume (GTask *task)
{
    InjectAssistanceDataContext *ctx = g_task_get_task_data (task);

    if (!ctx->response_received || !ctx->indication_received)
        return;
    loc_injection_clear_wait (ctx);
    if (ctx->indication_error) {
        g_task_return_error (task, g_steal_pointer (&ctx->indication_error));
        g_object_unref (task);
        return;
    }
    ctx->next_part (task);
}

static void
loc_injection_indicated (GTask *task, GError *error)
{
    InjectAssistanceDataContext *ctx = g_task_get_task_data (task);

    if (ctx->indication_received) {
        g_clear_error (&error);
        return;
    }
    ctx->indication_received = TRUE;
    ctx->indication_error = error;
    loc_injection_consume (task);
}

static void
loc_injection_acknowledged (GTask *task)
{
    InjectAssistanceDataContext *ctx = g_task_get_task_data (task);

    ctx->response_received = TRUE;
    if (!ctx->indication_received)
        ctx->timeout_id = g_timeout_add_seconds (10,
            (GSourceFunc)loc_location_inject_data_indication_timed_out, task);
    loc_injection_consume (task);
}

static void
loc_injection_subscribe (GTask *task, const gchar *signal, GCallback callback,
                        void (*next_part) (GTask *task))
{
    InjectAssistanceDataContext *ctx = g_task_get_task_data (task);

    g_assert (!ctx->indication_id && !ctx->timeout_id);
    ctx->response_received = FALSE;
    ctx->indication_received = FALSE;
    g_clear_error (&ctx->indication_error);
    ctx->next_part = next_part;
    ctx->indication_id = g_signal_connect (ctx->client, signal, callback, task);
}

'''
assert part.count(marker)==1;part=part.replace(marker,helpers+marker)
for kind,next_name in [('xtra_data','inject_xtra_data_next'),('predicted_orbits_data','inject_assistance_data_next')]:
    cb='loc_location_inject_'+kind+'_indication_cb'
    begin=part.index('static void\n'+cb+' (')
    finish=part.index('\nstatic void\n',begin+1)
    body=part[begin:finish]
    body=body.replace('    InjectAssistanceDataContext *ctx;\n','')
    # Preserve the original indication-status decoder and its errors.
    out=body.index('out:\n')
    body=body[:out]+'out:\n    loc_injection_indicated (task, error);\n}\n'
    part=part[:begin]+body+part[finish:]
    # Move subscription out of the command callback to before sending.
    signal='inject-'+kind.replace('_','-')
    pattern=(r'    /\* The task ownership is shared between signal and timeout; the one which is\n'
             r'     \* scheduled first will cancel the other\. \*/\n'
             r'    ctx->indication_id = g_signal_connect \(ctx->client,\n'
             r'\s+"'+signal+r'",\n\s+G_CALLBACK \('+cb+r'\),\n'
             r'\s+task\);\n    ctx->timeout_id = g_timeout_add_seconds \(10,\n'
             r'\s+\(GSourceFunc\)loc_location_inject_data_indication_timed_out,\n\s+task\);')
    part,count=re.subn(pattern,'    loc_injection_acknowledged (task);',part)
    assert count==1,(kind,count)
    needle='    qmi_client_loc_inject_'+kind+' (ctx->client,'
    assert part.count(needle)==1
    part=part.replace(needle,'    loc_injection_subscribe (task, "'+signal+'",\n'
        '        G_CALLBACK ('+cb+'), '+next_name+');\n'+needle)
part=part.replace('            g_error_free (error);\n            inject_xtra_data (task);',
    '            g_error_free (error);\n            loc_injection_clear_wait (ctx);\n            inject_xtra_data (task);')
# ctx is only needed in the predicted-orbits callback for fallback cleanup.
begin=part.index('static void\ninject_xtra_data_ready (');finish=part.index('\nstatic void\n',begin+1)
body=part[begin:finish]
body=re.sub(r'    InjectAssistanceDataContext\s+\*ctx;\n','',body)
body=body.replace('    ctx = g_task_get_task_data (task);\n\n','')
part=part[:begin]+body+part[finish:]
new=new[:start]+part+new[end:]
patch='Handle each LOC orbit-injection chunk indication in either response order.\nPreserve bounds, fallback and serial transfer; never advance before acknowledgement.\n\n'
patch+=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/src/mm-shared-qmi.c',tofile='b/src/mm-shared-qmi.c'))
package=workspace/'port/modemmanager'
(package/'loc-assistance-injection-order.patch').write_text(patch,newline='\n')
recipe=package/'APKBUILD';text=recipe.read_text()
assert re.search(r'^pkgrel=(4|5)$',text,re.M)
text=re.sub(r'^pkgrel=4$','pkgrel=5',text,flags=re.M)
if '\tloc-assistance-injection-order.patch\n' not in text:
    text=text.replace('\tloc-assistance-discovery-order.patch\n','\tloc-assistance-discovery-order.patch\n\tloc-assistance-injection-order.patch\n')
recipe.write_text(text,newline='\n')
recipe=workspace/'port/gps-gta4l/APKBUILD';text=recipe.read_text()
assert re.search(r'^pkgrel=(4|5)$',text,re.M)
text=re.sub(r'^pkgrel=4$','pkgrel=5',text,flags=re.M)
text=text.replace('modemmanager=1.25.95_git20261005-r4','modemmanager=1.25.95_git20261005-r5')
recipe.write_text(text,newline='\n')
print('GPS_ASSISTANCE_INJECTION_ORDER_FIX_PREPARED')
