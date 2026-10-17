#!/usr/bin/env python3
"""Read older official Mesa sources for a Zink Vulkan-1.0 candidate."""
from pathlib import Path
import hashlib,json,re,tarfile,urllib.request
root=Path('/home/ark/sm-t505-port')
cache=root/'work/cache_distfiles'
source=root/'diagnostics/mesa-gpu-source'
records=[]
for version in ('26.0.8','25.3.6'):
    archive=cache/('mesa-'+version+'.tar.xz')
    url='https://archive.mesa3d.org/'+archive.name
    if not archive.exists():
        print('Fetching official Mesa release:',version,flush=True)
        with urllib.request.urlopen(url,timeout=30) as response:
            data=response.read(100*1024*1024+1)
        assert len(data)<=100*1024*1024
        temp=archive.with_suffix('.download')
        temp.write_bytes(data)
        temp.replace(archive)
    data=archive.read_bytes()
    with tarfile.open(archive,'r:xz') as tar:
        text=tar.extractfile('mesa-'+version+'/src/gallium/drivers/zink/zink_device_info.py').read().decode()
        block=re.search(r'Extension\("VK_KHR_maintenance5".*?\),',text,re.S).group(0)
        required='required=True' in block
        record={'version':version,'url':url,'sha256':hashlib.sha256(data).hexdigest(),
                'sha512':hashlib.sha512(data).hexdigest(),'requires_maintenance5':required}
        records.append(record)
        print(json.dumps(record),flush=True)
        print(block,flush=True)
        if not required:
            source.mkdir(parents=True,exist_ok=True)
            # Official archive contents only, restricted to this extraction root.
            tar.extractall(source,filter='data')
            break
else:
    raise RuntimeError('These older releases also require maintenance5')
(source/'compatible-release.json').write_text(json.dumps(records[-1],indent=2)+'\n')
