"""Inventory stock camera filenames without executing Android binaries."""
from pathlib import Path
import json
import subprocess

image=Path('/home/ark/sm-t505-port/stock/vendor/vendor.img')
ws=Path('/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os')
directories=['/lib64/hw','/lib64','/lib64/camera','/lib/camera','/etc/camera','/etc/init','/etc/vintf/manifest']
result={}
for directory in directories:
    p=subprocess.run(['debugfs','-R','ls -p '+directory,str(image)],text=True,capture_output=True,check=True)
    selected=[]
    for row in p.stdout.splitlines():
        fields=row.split('/')
        if len(fields)<7: continue
        name=fields[5]
        if name in ('.','..'): continue
        if '/camera' in directory or any(term in name.lower() for term in ('camera','camx','mmcam','chi.','sensor')):
            selected.append(dict(name=name,size=fields[6],mode=fields[2]))
    result[directory]=selected
    print(directory+': '+str(len(selected))+' camera-related entries')
(ws/'evidence/stock-camera-layout.json').write_text(json.dumps(result,indent=2)+'\n')
print('Saved local stock camera filename inventory; no tablet changes')
