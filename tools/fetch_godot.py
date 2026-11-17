from pathlib import Path
import argparse,hashlib,urllib.request,zipfile
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--version',default='4.7.2');parser.add_argument('--output',default='.tools/godot');args=parser.parse_args()
 out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True)
 binary=out/'Godot';marker=out/'version.txt'
 if binary.exists() and marker.exists() and marker.read_text().strip()==args.version:
  print('Official Godot binary already available');return
 name=f'Godot_v{args.version}-stable_linux.x86_64.zip'
 base=f'https://github.com/godotengine/godot-builds/releases/download/{args.version}-stable/'
 def read(url):
  req=urllib.request.Request(url,headers={'User-Agent':'eyes-of-dusk-pages-build'})
  with urllib.request.urlopen(req,timeout=180) as response:return response.read()
 payload=read(base+name);checks=read(base+'SHA512-SUMS.txt').decode('utf-8')
 expected=next(line.split()[0] for line in checks.splitlines() if line.split()[-1].lstrip('*')==name)
 if hashlib.sha512(payload).hexdigest()!=expected:raise RuntimeError('Official Godot SHA-512 mismatch')
 archive_path=out/name;archive_path.write_bytes(payload)
 with zipfile.ZipFile(archive_path) as archive:
  member=next(info for info in archive.infolist() if not info.is_dir() and 'linux.x86_64' in info.filename)
  binary.write_bytes(archive.read(member))
 binary.chmod(0o755);marker.write_text(args.version+'\n',encoding='utf-8')
 print('Official Godot '+args.version+' downloaded and SHA-512 verified')
if __name__=='__main__':main()
