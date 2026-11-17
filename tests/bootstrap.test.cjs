const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const template=fs.readFileSync(require.resolve('../web/index.template.html'),'utf8');
const source=template.split('<script>')[1].split('</script>')[0].replace('__BUILD_ID__','test-build').replace('__ENGINE_CONFIG__',JSON.stringify({fileSizes:{'index.wasm':10}})).replace('__COVER_LAYOUT__',JSON.stringify({labels:[{text:'带上她的眼睛',position:[152,221],box:[316,58],font_size:48}],button:{text:'开 始 游 戏',position:[152,508.5],box:[298,76],font_size:24}})).replace('void loadGame();','globalThis.testBoot=loadGame();');
function page(options={}){
 const elements={};function element(id){return elements[id]||(elements[id]={style:{setProperty(){}},className:'',textContent:'',children:[],appendChild(v){this.children.push(v);},addEventListener(){},remove(){this.removed=true;},focus(){this.focused=true;}});}
 element('loading');
 const events=[],manifest={build_id:options.newBuild?'newBuild':'test-build',pack_bytes:8},responses=[];
 class Engine{
  static getMissingFeatures(){return [];}
  constructor(config){this.config=config;}
  async init(){events.push('engine-init');if(options.engineReject)throw new Error('engine failure');if(options.barriers)await options.barriers.engine;}
  async preloadFile(buffer,name){assert.equal(name,'index.pck');assert.equal(buffer.byteLength,8);events.push('preload');}
  async start(){events.push(['start',this.config.args]);}
 }
 const context={Engine,document:{getElementById:element,createElement:()=>element('label'+Object.keys(elements).length)},location:{href:'https://game.example/eyes/'+(options.search||''),search:options.search||'',replace:url=>events.push(['redirect',url])},navigator:{},innerWidth:1280,innerHeight:800,addEventListener(){},AbortController,URL,URLSearchParams,setTimeout,clearTimeout,console:{info(){},error(){}},fetch:async()=>({ok:true,json:async()=>manifest}),EyesDownload:{loadPack:async(m,opts)=>{events.push('pack-download');responses.push(opts);if(options.barriers)await options.barriers.pack;return {pack:new Uint8Array(8),stats:{}};}}};
 vm.createContext(context);vm.runInContext(source,context);return {context,elements,events,responses};
}
test('downloads engine and the full pack concurrently before enabling the native Start menu',async()=>{
 let engineReady,packReady;
 const p=page({barriers:{engine:new Promise(r=>engineReady=r),pack:new Promise(r=>packReady=r)}});
 await new Promise(r=>setImmediate(r));assert.deepEqual(p.events,['engine-init','pack-download']);assert.ok(!p.elements.loading.removed);
 engineReady();packReady();await p.context.testBoot;
 assert.equal(p.elements.loading.removed,true);assert.equal(p.elements.canvas.focused,true);
 assert.equal(p.elements['cover-stage'].children[0].textContent,'带上她的眼睛');assert.equal(p.elements.enter.style.left,'11.875%');
 assert.deepEqual(p.events.slice(0,3),['engine-init','pack-download','preload']);
});
test('chapter links and the transparent Earth preview preserve their game arguments',async()=>{
 for(const [search,argument] of [['?chapter=3','--web-chapter=3'],['?scene=core','--preview-earth-core']]){
  const p=page({search});await p.context.testBoot;assert.ok(p.events.find(e=>Array.isArray(e)&&e[0]==='start')[1].includes(argument));
 }
});
test('version mismatch refreshes before downloading incompatible resources',async()=>{
 const p=page({newBuild:true});await p.context.testBoot;assert.equal(p.events[0][0],'redirect');assert.match(p.events[0][1],/_v=newBuild/);assert.ok(!p.events.includes('pack-download'));
});
test('engine failure aborts the active transfer and leaves a usable resume button',async()=>{
 const p=page({engineReject:true});await p.context.testBoot;assert.equal(p.responses[0].signal.aborted,true);assert.equal(p.elements.enter.disabled,false);assert.match(p.elements.failure.textContent,/engine failure/);assert.ok(!p.elements.loading.removed);
});
