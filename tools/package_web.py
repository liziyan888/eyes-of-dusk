from pathlib import Path
import argparse, hashlib, json, re, shutil

ROOT=Path(__file__).resolve().parents[1]
DIST=ROOT/'dist'

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(4*1024*1024),b''):h.update(block)
    return h.hexdigest()

def package():
    pack=DIST/'index.pck'
    html=DIST/'index.html'
    if not pack.is_file():raise RuntimeError('Expected fresh Godot index.pck export')
    with pack.open('rb') as stream:
        if stream.read(4)!=b'GDPC':raise RuntimeError('Invalid Godot resource pack')
    match=re.search(r'const GODOT_CONFIG = (\{[^\r\n]+\});',html.read_text(encoding='utf-8'))
    if not match:raise RuntimeError('Godot export configuration missing from index.html')
    config=json.loads(match.group(1))
    pack_hash=digest(pack);build_id=pack_hash[:16]
    parts_dir=DIST/'game-data'
    parts_dir.mkdir(parents=True,exist_ok=True)
    parts=[];reassembled=hashlib.sha256();offset=0
    with pack.open('rb') as stream:
        index=0
        while True:
            block=stream.read(32*1024*1024)
            if not block:break
            part_digest=hashlib.sha256(block).hexdigest()
            dest=parts_dir/f'part-{part_digest}.bin'
            dest.write_bytes(block)
            part_hash=digest(dest)
            if part_hash!=hashlib.sha256(block).hexdigest():raise RuntimeError('Resource fragment verification failed')
            reassembled.update(dest.read_bytes())
            parts.append({'file':dest.relative_to(DIST).as_posix(),'offset':offset,'bytes':len(block),'sha256':part_hash})
            offset+=len(block);index+=1
    if reassembled.hexdigest()!=pack_hash or offset!=pack.stat().st_size:raise RuntimeError('Lossless resource assembly verification failed')
    manifest={'title':'带上她的眼睛','build_id':build_id,'godot_version':'4.7.2','pack_bytes':offset,'pack_sha256':pack_hash,'parts':parts,'engine_config':config,'resource_processing':'Original game resources; byte-identical pack split into 32 MiB parts, no image/video/audio re-encoding'}
    (DIST/'release-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    template=(ROOT/'web/index.template.html').read_text(encoding='utf-8')
    template=template.replace('__BUILD_ID__',build_id).replace('__ENGINE_CONFIG__',json.dumps(config,ensure_ascii=False,separators=(',',':')))
    html.write_text(template,encoding='utf-8')
    worker=(ROOT/'web/cache-worker.template.js').read_text(encoding='utf-8').replace('__BUILD_ID__',build_id)
    (DIST/'cache-worker.js').write_text(worker,encoding='utf-8')
    shutil.copy2(ROOT/'game/assets/prologue/cover-cinematic.png',DIST/'cover.png')
    (DIST/'.nojekyll').touch()
    # Only remove this verified, generated duplicate inside the export folder.
    if pack.resolve().parent!=DIST.resolve():raise RuntimeError('Unexpected export path')
    pack.unlink()
    for old in (DIST/'game-data').iterdir():
        if old.is_dir() and old.name!=build_id and re.fullmatch(r'[a-f0-9]{16}',old.name):
            if not old.resolve().is_relative_to(DIST.resolve()):raise RuntimeError('Unsafe old export path')
            shutil.rmtree(old)
        elif old.is_file() and re.fullmatch(r'part-[a-f0-9]{64}\.bin',old.name) and old.relative_to(DIST).as_posix() not in {part['file'] for part in parts}:
            if not old.resolve().is_relative_to(DIST.resolve()):raise RuntimeError('Unsafe old resource fragment path')
            old.unlink()
    total=sum(p.stat().st_size for p in DIST.rglob('*') if p.is_file())
    if total>1_000_000_000:raise RuntimeError(f'Pages site exceeds conservative 1 GB budget: {total}')
    print(json.dumps({'build_id':build_id,'pack_bytes':offset,'resource_parts':len(parts),'largest_part':max(p['bytes'] for p in parts),'published_bytes':total,'lossless_assembly_verified':True},ensure_ascii=False,indent=2))
    return manifest
if __name__=='__main__':package()
