/* SPDX-License-Identifier: GPL-2.0
 * Extracted from Samsung sm6115 adsprpc_shared.h, commit
 * 381a5549ee66fa751f632ee0840f5631274209ee.
 * Copyright (c) 2012-2020, The Linux Foundation. All rights reserved.
 */
#define remote_arg64_t    union remote_arg64

struct remote_buf64 {
	uint64_t pv;
	uint64_t len;
};

struct remote_dma_handle64 {
	int fd;
	uint32_t offset;
	uint32_t len;
};

union remote_arg64 {
	struct remote_buf64	buf;
	struct remote_dma_handle64 dma;
	uint32_t h;
};

#define remote_arg_t    union remote_arg

struct remote_buf {
	void *pv;		/* buffer pointer */
	size_t len;		/* length of buffer */
};

struct remote_dma_handle {
	int fd;
	uint32_t offset;
};

union remote_arg {
	struct remote_buf buf;	/* buffer info */
	struct remote_dma_handle dma;
	uint32_t h;		/* remote handle */
};

struct fastrpc_ioctl_invoke {
	uint32_t handle;	/* remote handle */
	uint32_t sc;		/* scalars describing the data */
	remote_arg_t *pra;	/* remote arguments list */
};

struct fastrpc_ioctl_invoke_fd {
	struct fastrpc_ioctl_invoke inv;
	int *fds;		/* fd list */
};

struct fastrpc_ioctl_invoke_attrs {
	struct fastrpc_ioctl_invoke inv;
	int *fds;		/* fd list */
	unsigned int *attrs;	/* attribute list */
};

struct fastrpc_ioctl_invoke_crc {
	struct fastrpc_ioctl_invoke inv;
	int *fds;		/* fd list */
	unsigned int *attrs;	/* attribute list */
	unsigned int *crc;
};

struct fastrpc_ioctl_init {
	uint32_t flags;		/* one of FASTRPC_INIT_* macros */
	uintptr_t file;		/* pointer to elf file */
	uint32_t filelen;	/* elf file length */
	int32_t filefd;		/* ION fd for the file */
	uintptr_t mem;		/* mem for the PD */
	uint32_t memlen;	/* mem length */
	int32_t memfd;		/* ION fd for the mem */
};

struct fastrpc_ioctl_init_attrs {
		struct fastrpc_ioctl_init init;
		int attrs;
		unsigned int siglen;
};

struct fastrpc_ioctl_munmap {
	uintptr_t vaddrout;	/* address to unmap */
	size_t size;		/* size */
};

struct fastrpc_ioctl_munmap_64 {
	uint64_t vaddrout;	/* address to unmap */
	size_t size;		/* size */
};

struct fastrpc_ioctl_mmap {
	int fd;					/* ion fd */
	uint32_t flags;			/* flags for dsp to map with */
	uintptr_t vaddrin;		/* optional virtual address */
	size_t size;			/* size */
	uintptr_t vaddrout;		/* dsps virtual address */
};

struct fastrpc_ioctl_mmap_64 {
	int fd;				/* ion fd */
	uint32_t flags;			/* flags for dsp to map with */
	uint64_t vaddrin;		/* optional virtual address */
	size_t size;			/* size */
	uint64_t vaddrout;		/* dsps virtual address */
};

