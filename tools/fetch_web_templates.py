"""Fetch only matching official Web templates from the release archive.
HTTPS Range reads avoid downloading unrelated desktop/mobile templates.
"""
from pathlib import Path
import io, json, urllib.request, zipfile, argparse, hashlib

class RemoteZip(io.RawIOBase):
    def __init__(self, url, size):
        self.url=url; self.size=size; self.position=0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position=offset if whence==0 else self.position+offset if whence==1 else self.size+offset
        return self.position
    def read(self, size=-1):
        if size<0: size=self.size-self.position
        size=min(size,self.size-self.position)
        if size<=0: return b''
        start=self.position; end=start+size-1
        request=urllib.request.Request(self.url, headers={'User-Agent':'Codex-game-publisher','Range':f'bytes={start}-{end}'})
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status!=206: raise RuntimeError(f'Official archive did not honor byte ranges: {response.status}')
            content_range=response.headers.get('Content-Range','')
            if not content_range.startswith(f'bytes {start}-{end}/'):
                raise RuntimeError(f'Unexpected archive range: {content_range}')
            payload=response.read(size+1)
        if len(payload)!=size: raise RuntimeError('Incomplete archive range')
        self.position+=len(payload)
        return payload

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--version',default='4.7.2')
    parser.add_argument('--output',required=True)
    args=parser.parse_args()
    out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
    release_url=f'https://api.github.com/repos/godotengine/godot-builds/releases/tags/{args.version}-stable'
    req=urllib.request.Request(release_url,headers={'User-Agent':'Codex-game-publisher'})
    release=json.load(urllib.request.urlopen(req,timeout=60))
    asset=next(a for a in release['assets'] if a['name']==f'Godot_v{args.version}-stable_export_templates.tpz')
    records=[]
    archive=zipfile.ZipFile(RemoteZip(asset['browser_download_url'],asset['size']))
    wanted=['templates/web_nothreads_release.zip']
    for name in wanted:
        dest=out/Path(name).name
        if not dest.exists():
            print(f'Fetching {name}',flush=True)
            payload=archive.read(name)
            dest.write_bytes(payload)
        with zipfile.ZipFile(dest) as template:
            bad=template.testzip()
            if bad: raise RuntimeError(f'Template CRC failure: {bad}')
        records.append({'file':dest.name,'bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'source':asset['browser_download_url'],'version':args.version})
        print(json.dumps(records[-1]),flush=True)
    (out/'manifest.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
if __name__=='__main__':main()
