/* ARM EABI syscall-table regression; no libc or Android runtime dependency. */
.syntax unified
.arm
.global _start
.text
_start:
    mvn r0, #99                 /* AT_FDCWD (-100) */
    ldr r1, =existing
    mov r2, #0                  /* F_OK */
    mov r3, #0x300              /* AT_EACCESS | AT_SYMLINK_NOFOLLOW */
    mov r7, #439
    svc #0
    cmp r0, #0
    bne failed

    mvn r0, #99
    ldr r1, =missing
    mov r2, #0
    mov r3, #0x100
    mov r7, #439
    svc #0
    cmn r0, #2                  /* -ENOENT */
    bne failed

    mvn r0, #99
    ldr r1, =existing
    mov r2, #8                  /* invalid access mode */
    mov r3, #0
    mov r7, #439
    svc #0
    cmn r0, #22                 /* -EINVAL */
    bne failed

    mov r0, #1
    ldr r1, =success
    ldr r2, =success_end-success
    mov r7, #4                  /* write */
    svc #0
    mov r0, #0
    b finish
failed:
    mov r0, #1
finish:
    mov r7, #1                  /* exit */
    svc #0
.section .rodata
existing: .asciz "/proc/version"
missing: .asciz "/proc/gta4l-faccessat2-nonexistent-fixture"
success: .ascii "ARM32_FACCESSAT2_COMPAT_PASS\n"
success_end:
