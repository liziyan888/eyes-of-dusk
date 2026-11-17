from pathlib import Path
import argparse, gzip, hashlib, io, json, re, shutil

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
    previous=None
    if not pack.is_file() and (DIST/'release-manifest.json').is_file():
        previous=json.loads((DIST/'release-manifest.json').read_text(encoding='utf-8'))
        with pack.open('wb') as target:
            for part in previous['parts']:
                source=(DIST/part.get('download_file',part['file'])).resolve()
                if not source.is_relative_to(DIST.resolve()) or digest(source)!=part.get('download_sha256',part['sha256']):
                    raise RuntimeError('Existing export fragment verification failed')
                payload=source.read_bytes()
                if part.get('encoding')=='gzip':payload=gzip.decompress(payload)
                if len(payload)!=part['bytes'] or hashlib.sha256(payload).hexdigest()!=part['sha256']:raise RuntimeError('Existing export decoded fragment verification failed')
                target.write(payload)
        if digest(pack)!=previous['pack_sha256']:raise RuntimeError('Existing export reconstruction failed')
    if not pack.is_file():raise RuntimeError('Expected fresh Godot index.pck export')
    with pack.open('rb') as stream:
        if stream.read(4)!=b'GDPC':raise RuntimeError('Invalid Godot resource pack')
    match=re.search(r'const GODOT_CONFIG = (\{[^\r\n]+\});',html.read_text(encoding='utf-8'))
    if not match and previous is None:raise RuntimeError('Godot export configuration missing from index.html')
    config=json.loads(match.group(1)) if match else previous['engine_config']
    pack_hash=digest(pack)
    template=(ROOT/'web/index.template.html').read_text(encoding='utf-8')
    loader=(ROOT/'web/downloader.js').read_text(encoding='utf-8')
    worker_template=(ROOT/'web/cache-worker.template.js').read_text(encoding='utf-8')
    cover=cover_layout()
    engine_hash=digest(DIST/'index.wasm')
    build_id=hashlib.sha256(('lossless-gzip-v3'+pack_hash+engine_hash+template+loader+worker_template+json.dumps(cover,sort_keys=True)).encode()).hexdigest()[:16]
    parts_dir=DIST/'game-data'
    parts_dir.mkdir(parents=True,exist_ok=True)
    parts=[];reassembled=hashlib.sha256();offset=0;published_parts=set();transfer_bytes=0
    with pack.open('rb') as stream:
        index=0
        while True:
            block=stream.read(4*1024*1024)
            if not block:break
            part_digest=hashlib.sha256(block).hexdigest()
            # Keep the old uncompressed content-addressed cache key. Existing
            # visitors can reuse verified fragments without downloading gzip.
            logical_file=f'game-data/part-{part_digest}.bin'
            descriptor={'file':logical_file,'offset':offset,'bytes':len(block),'sha256':part_digest}
            stream_buffer=io.BytesIO()
            with gzip.GzipFile(filename='',mode='wb',fileobj=stream_buffer,compresslevel=6,mtime=0) as archive:archive.write(block)
            encoded=stream_buffer.getvalue()
            if len(encoded)<=len(block)*.98:
                encoded_hash=hashlib.sha256(encoded).hexdigest()
                descriptor.update({'encoding':'gzip','download_file':f'game-data/packed-{encoded_hash}.bin','download_bytes':len(encoded),'download_sha256':encoded_hash})
                if gzip.decompress(encoded)!=block:raise RuntimeError('Lossless decompression verification failed')
                payload=encoded
            else:payload=block
            published_file=descriptor.get('download_file',logical_file)
            dest=DIST/published_file;dest.write_bytes(payload)
            if digest(dest)!=descriptor.get('download_sha256',part_digest):raise RuntimeError('Resource fragment verification failed')
            published_parts.add(published_file);transfer_bytes+=len(payload)
            reassembled.update(gzip.decompress(dest.read_bytes()) if descriptor.get('encoding')=='gzip' else dest.read_bytes())
            parts.append(descriptor)
            offset+=len(block);index+=1
    if reassembled.hexdigest()!=pack_hash or offset!=pack.stat().st_size:raise RuntimeError('Lossless resource assembly verification failed')
    manifest={'title':'带上她的眼睛','build_id':build_id,'godot_version':'4.7.2','pack_bytes':offset,'transfer_bytes':transfer_bytes,'pack_sha256':pack_hash,'parts':parts,'engine_config':config,'engine_sha256':engine_hash,'transport_version':3,'resource_processing':'Original game resources; byte-identical pack in verified 4 MiB fragments, lossless gzip transport when smaller, partial HTTP resume and bounded parallel cache reads. No image/video/audio re-encoding.'}
    legacy_path=ROOT/'web/legacy-pack.json'
    if legacy_path.is_file():
        legacy=json.loads(legacy_path.read_text(encoding='utf-8'))
        manifest['legacy_pack_sha256']=legacy['pack_sha256']
        manifest['legacy_parts']=legacy['parts']
    (DIST/'release-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    template=template.replace('__BUILD_ID__',build_id).replace('__ENGINE_CONFIG__',json.dumps(config,ensure_ascii=False,separators=(',',':'))).replace('__COVER_LAYOUT__',json.dumps(cover,ensure_ascii=False,separators=(',',':')))
    html.write_text(template,encoding='utf-8')
    (DIST/'downloader.js').write_text(loader,encoding='utf-8')
    worker=worker_template.replace('__BUILD_ID__',build_id).replace('__ENGINE_SHA256__',engine_hash)
    (DIST/'cache-worker.js').write_text(worker,encoding='utf-8')
    shutil.copy2(ROOT/'game/assets/prologue/cover-cinematic.png',DIST/'cover.png')
    shutil.copy2(ROOT/'game/assets/web-fonts/SimSun.ttf',DIST/'cover-font.ttf')
    (DIST/'.nojekyll').touch()
    # Only remove this verified, generated duplicate inside the export folder.
    if pack.resolve().parent!=DIST.resolve():raise RuntimeError('Unexpected export path')
    pack.unlink()
    for old in (DIST/'game-data').iterdir():
        if old.is_dir() and old.name!=build_id and re.fullmatch(r'[a-f0-9]{16}',old.name):
            if not old.resolve().is_relative_to(DIST.resolve()):raise RuntimeError('Unsafe old export path')
            shutil.rmtree(old)
        elif old.is_file() and re.fullmatch(r'(?:part|packed)-[a-f0-9]{64}\.bin',old.name) and old.relative_to(DIST).as_posix() not in published_parts:
            if not old.resolve().is_relative_to(DIST.resolve()):raise RuntimeError('Unsafe old resource fragment path')
            old.unlink()
    total=sum(p.stat().st_size for p in DIST.rglob('*') if p.is_file())
    if total>1_000_000_000:raise RuntimeError(f'Pages site exceeds conservative 1 GB budget: {total}')
    print(json.dumps({'build_id':build_id,'pack_bytes':offset,'transfer_bytes':transfer_bytes,'saved_transfer_bytes':offset-transfer_bytes,'resource_parts':len(parts),'compressed_parts':sum(p.get('encoding')=='gzip' for p in parts),'largest_part':max(p['bytes'] for p in parts),'published_bytes':total,'lossless_assembly_verified':True},ensure_ascii=False,indent=2))
    return manifest

def cover_layout():
    """Mirror the existing saved Godot title, text boxes and Start position."""
    rows=[{'source':'带 上 她 的','text':'带 上 她 的','position':[205,132],'box':[460,112],'font_size':38},
          {'source':'眼 睛','text':'眼 睛','position':[205,188],'box':[460,112],'font_size':84}]
    button={'text':'开 始 游 戏','position':[248,531],'box':[298,76],'font_size':24}
    path=ROOT/'game/data/text_overrides.json'
    entries=json.loads(path.read_text(encoding='utf-8-sig')).get('entries',{}) if path.is_file() else {}
    for spec in entries.values():
        context=spec.get('context','')
        if '/prologue_cover/' not in context:continue
        target=button if context.endswith('/prologue_cover/Button[0]') else next((row for row in rows if row['source']==spec.get('source')),None)
        if target is not None:
            for key in ['text','position','box','font_size','font_color','alignment','font_style']:
                if key in spec:target[key]=spec[key]
    return {'labels':rows,'button':button}
if __name__=='__main__':package()
