from pathlib import Path
import json,re,sys
ROOT=Path(__file__).resolve().parents[1]
TEXT_EXT={'.gd','.gdshader','.json','.tscn','.tres','.godot','.cfg','.html','.js','.css','.md','.yml','.yaml','.py','.ps1','.bat','.sh','.txt'}
RULES={
 'GitHub token':re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{28,}|github_pat_[A-Za-z0-9_]{30,})\b'),
 'service API key':re.compile(r'\bsk-(?:proj-|ant-|svcacct-)?[A-Za-z0-9_-]{24,}\b'),
 'AWS key':re.compile(r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'),
 'private key':re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'),
 'JWT':re.compile(r'\beyJ[A-Za-z0-9_-]{12,}\.eyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{16,}\b'),
 'credential assignment':re.compile(r'''(?i)["']?(?:api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|password|passwd)["']?\s*[:=]\s*["'](?!\$\{|<|YOUR_|your_|example|placeholder)([^"'\r\n]{12,})["']'''),
 'credential in URL':re.compile(r'''(?i)[?&](?:api[_-]?key|access_token|auth_token|x-amz-signature|x-oss-signature)=[^&\s"'\\]{12,}'''),
}
def scan():
 findings=[];count=0
 for path in ROOT.rglob('*'):
  if not path.is_file() or any(p in {'.git','.godot','.web-templates','.tools','dist'} for p in path.relative_to(ROOT).parts):continue
  if path.name.startswith('.env'):
   findings.append({'file':str(path.relative_to(ROOT)),'line':1,'type':'environment file'});continue
  if path.suffix.lower() not in TEXT_EXT or path.stat().st_size>20_000_000:continue
  text=path.read_text(encoding='utf-8-sig',errors='replace');count+=1
  for label,rule in RULES.items():
   for match in rule.finditer(text):
    findings.append({'file':path.relative_to(ROOT).as_posix(),'line':text.count('\n',0,match.start())+1,'type':label})
 result={'text_files_scanned':count,'credential_findings':findings}
 print(json.dumps(result,ensure_ascii=False,indent=2))
 if findings:raise RuntimeError('Potential credential found; publication stopped. No matched value printed.')
 return result
if __name__=='__main__':scan()
