/* Device-selected LOC preparation. Wait for both the request acknowledgement
 * and the completion indication before starting the normal GPS session. */
typedef struct {
    QmiClientLoc *client;
    gulong        indication_id;
    guint         timeout_id;
    gboolean      response_received;
    gboolean      indication_received;
    gboolean      finished;
} Gta4lLocUnlock;

static void
gta4l_loc_unlock_cleanup (Gta4lLocUnlock *ctx)
{
    if (ctx->indication_id) {
        g_signal_handler_disconnect (ctx->client, ctx->indication_id);
        ctx->indication_id = 0;
    }
    if (ctx->timeout_id) {
        g_source_remove (ctx->timeout_id);
        ctx->timeout_id = 0;
    }
}

static void
gta4l_loc_unlock_free (Gta4lLocUnlock *ctx)
{
    gta4l_loc_unlock_cleanup (ctx);
    g_clear_object (&ctx->client);
    g_free (ctx);
}

static void
gta4l_loc_unlock_progress (GTask *task, GError *error)
{
    Gta4lLocUnlock *ctx = g_task_get_task_data (task);

    if (ctx->finished) {
        g_clear_error (&error);
        return;
    }
    if (!error && !(ctx->response_received && ctx->indication_received))
        return;
    ctx->finished = TRUE;
    gta4l_loc_unlock_cleanup (ctx);
    if (error) {
        g_prefix_error (&error, "Couldn't prepare SM-T505 GPS engine: ");
        g_task_return_error (task, error);
        g_object_unref (task);
    } else
        loc_send_start (ctx->client, task);
}

static gboolean
gta4l_loc_unlock_timeout (GTask *task)
{
    Gta4lLocUnlock *ctx = g_task_get_task_data (task);

    ctx->timeout_id = 0;
    gta4l_loc_unlock_progress (task,
        g_error_new_literal (MM_CORE_ERROR, MM_CORE_ERROR_ABORTED,
                             "LOC engine-lock completion timed out"));
    return G_SOURCE_REMOVE;
}

static void
gta4l_loc_unlock_indication (QmiClientLoc *client,
                             QmiIndicationLocSetEngineLockOutput *output,
                             GTask *task)
{
    Gta4lLocUnlock *ctx = g_task_get_task_data (task);
    QmiLocIndicationStatus status;
    GError *error = NULL;

    if (ctx->finished)
        return;
    if (!qmi_indication_loc_set_engine_lock_output_get_indication_status (output, &status, &error) ||
        !mm_error_from_qmi_loc_indication_status (status, &error)) {
        gta4l_loc_unlock_progress (task, error);
        return;
    }
    ctx->indication_received = TRUE;
    gta4l_loc_unlock_progress (task, NULL);
}

static void
gta4l_loc_unlock_response (QmiClientLoc *client, GAsyncResult *res, GTask *task)
{
    /* The request owns an additional reference: a timeout or early indication
     * failure may finish the outer task before this callback arrives. */
    g_autoptr(GTask) callback_ref = task;
    g_autoptr(QmiMessageLocSetEngineLockOutput) output = NULL;
    g_autoptr(GError) error = NULL;
    Gta4lLocUnlock *ctx = g_task_get_task_data (task);

    output = qmi_client_loc_set_engine_lock_finish (client, res, &error);
    if (ctx->finished)
        return;
    if (!output || !qmi_message_loc_set_engine_lock_output_get_result (output, &error)) {
        gta4l_loc_unlock_progress (task, g_steal_pointer (&error));
        return;
    }
    ctx->response_received = TRUE;
    gta4l_loc_unlock_progress (task, NULL);
}

static void
gta4l_loc_unlock (QmiClientLoc *client, GTask *task)
{
    g_autoptr(QmiMessageLocSetEngineLockInput) input = NULL;
    Gta4lLocUnlock *ctx = g_new0 (Gta4lLocUnlock, 1);

    ctx->client = g_object_ref (client);
    g_task_set_task_data (task, ctx, (GDestroyNotify) gta4l_loc_unlock_free);
    ctx->indication_id = g_signal_connect (client, "set-engine-lock",
                                           G_CALLBACK (gta4l_loc_unlock_indication), task);
    ctx->timeout_id = g_timeout_add_seconds (15, (GSourceFunc) gta4l_loc_unlock_timeout, task);
    input = qmi_message_loc_set_engine_lock_input_new ();
    qmi_message_loc_set_engine_lock_input_set_lock_type (input, QMI_LOC_LOCK_TYPE_NONE, NULL);
    qmi_client_loc_set_engine_lock (client, input, 10, NULL,
                                    (GAsyncReadyCallback) gta4l_loc_unlock_response,
                                    g_object_ref (task));
}
