from pathlib import Path
import argparse,subprocess,json,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from check_source import scan
from package_web import package
def run(command,label):
 result=subprocess.run([str(c) for c in command],cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding='utf-8',errors='replace')
 (ROOT/(label+'.log')).write_text(result.stdout,encoding='utf-8')
 if result.returncode or 'SCRIPT ERROR:' in result.stdout or '\nERROR:' in result.stdout:
  print(result.stdout[-9000:])
  raise RuntimeError(label+' failed (exit code '+str(result.returncode)+')')
 print(label+' completed',flush=True)
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--godot',required=True);args=parser.parse_args()
 scan();(ROOT/'dist').mkdir(exist_ok=True)
 engine=Path(args.godot).resolve()
 run([engine,'--headless','--editor','--path',ROOT/'game','--import','--quit'],'web-import')
 run([engine,'--headless','--path',ROOT/'game','--export-release','Web',ROOT/'dist/index.html'],'web-export')
 package()
if __name__=='__main__':main()
