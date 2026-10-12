#!/usr/bin/env python3
"""Generate the small mapper adaptation against the pinned upstream source."""
from pathlib import Path
import difflib

root = Path(__file__).resolve().parents[1]
original = Path('/home/pmos/sm-t505-port/downloads/pd-mapper-v1.1.c').read_text()
needle = '\tclass_fd = open("/sys/class/remoteproc", O_RDONLY | O_DIRECTORY);'
insert = r'''	/* Downstream PIL exposes subsystem devices instead of remoteproc. */
	const char *override = getenv("PD_MAPPER_FW_DIR");
	if (override) {
		fw_dir = opendir(override);
		if (!fw_dir) {
			warn("failed to open firmware directory");
			return -1;
		}
		while ((fw_de = readdir(fw_dir)) != NULL) {
			len = strlen(fw_de->d_name);
			if (!((len > 4 && !strcmp(fw_de->d_name + len - 4, ".jsn")) ||
			      (len > 7 && !strcmp(fw_de->d_name + len - 7, ".jsn.xz"))))
				continue;
			if (snprintf(json_path, sizeof(json_path), "%s/%s", override,
				     fw_de->d_name) >= sizeof(json_path)) {
				closedir(fw_dir);
				return -1;
			}
			assoc_set(json_set, json_path, NULL);
		}
		closedir(fw_dir);
		return 0;
	}

'''
assert original.count(needle) == 1
modified = original.replace(needle, insert + needle)
needle = '\tfd = qrtr_open(0);'
insert = r'''	/* Validate stock manifests without contacting hardware. */
	if (argc == 2 && !strcmp(argv[1], "--check-maps")) {
		const struct pd_map *map = pd_maps;
		while (map->service) {
			printf("%s %s %d\n", map->service, map->domain, map->instance);
			map++;
		}
		return 0;
	}

'''
assert modified.count(needle) == 1
modified = modified.replace(needle, insert + needle)
patch = ''.join(difflib.unified_diff(original.splitlines(True), modified.splitlines(True),
                                   fromfile='a/pd-mapper.c', tofile='b/pd-mapper.c'))
(root / 'port/pd-mapper-gta4l/downstream-firmware.patch').write_text(patch, newline='\n')
