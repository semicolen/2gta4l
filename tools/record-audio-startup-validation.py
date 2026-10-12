#!/usr/bin/env python3
"""Record audio timing reproduction and the tested persistent repair."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]
folder=root/'evidence/diagnostic-boot-20261009'
names=('device-r21-audio-startup-timer-test.raw','device-r21-audio-startup-timer-log.raw',
       'device-r21-audio-startup-interrupt-test.raw','device-r21-audio-startup-r3-install.raw',
       'device-r21-audio-startup-persistent-r3-test.raw','device-r21-audio-bluetooth-receive-state.raw')
texts={name:(folder/name).read_text() for name in names}
def entries(name,prefix):
    return [json.loads(line[len(prefix):]) for line in texts[name].splitlines() if line.startswith(prefix)]
assert 'timed out after 16 seconds' in texts[names[0]]
assert 'Increasing minimal latency' in texts[names[1]] and 'Underrun!' in texts[names[1]]
temporary=entries(names[2],'AUDIO_INTERRUPT_TRIAL_RESULT=')
persistent=entries(names[4],'AUDIO_PERSISTENT_TRIAL_RESULT=')
assert len(temporary)==len(persistent)==2
assert all(item['status']==0 and 7.7<item['elapsed']<9.2 for item in temporary+persistent)
assert 'AUDIO_STARTUP_R3_INSTALLED_BOOT_UNCHANGED' in texts[names[3]]
assert 'AUDIO_PERSISTENT_TEST_END' in texts[names[4]]
counts=entries(names[4],'PERSISTENT_AUDIO_LOG_COUNTS=')[0]
assert counts['Underrun!']==0 and counts['Increasing minimal latency']==0
assert texts[names[4]].count('IDLE_PCM_BEFORE_TRIAL=closed')==2
assert 'IDLE_PCM_AFTER_TEST=closed' in texts[names[4]]
bt=entries(names[5],'BLUETOOTH_RECEIVE_AUDIO_STATE=')[0]
report=json.loads((root/'artifacts/audio-startup-verification.json').read_text())
report.update(
    audio_release=3,kernel_release=9,device_release=21,
    post_install_verified=True,persistent_restart_verified=True,normal_boot_verified=False,
    timer_mode_eight_second_tone_timed_out_at_seconds=16,
    temporary_interrupt_trials=temporary,persistent_cold_start_trials=persistent,
    persistent_log_counts=counts,idle_pcm_shutdown_verified=True,
    client_sample_rates_tested_hz=[48000,44100],client_requested_latency_ms=30,
    driver_timing='Q6 PCM pointer advances on completed DSP blocks',
    hardware_pcm_period_ms=10,hardware_pcm_periods=4,buffer_duration_ms=40,
    user_confirmed_bluetooth_receiver_audible_and_smooth_from_start=True,
    bluetooth_receive_snapshot=bt,
    speaker_firmware_unchanged=True,kernel_and_boot_unchanged=True,
    amplifier_gain_and_calibration_unchanged=True,external_card_auto_detection_retained=True,
    microphone_verified=False,bluetooth_transmit_or_headset_verified=False,suspend_verified=False,
    hours_long_audio_playback_verified=False,
    evidence_sha256={name:hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in names},
    source_archive_sha256='e009e61f6a6c5d145aa87bcde6bb3c36680683b9f05fc5780f8e008034854137')
(root/'artifacts/audio-startup-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('AUDIO_STARTUP_R3_PERSISTENT_RESTART_AND_PCM_TIMING_VERIFIED')
