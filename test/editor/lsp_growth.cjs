// Real stdio LSP workload: tokens immediately followed by completion, edits,
// recovery and response decoding. No mocked server or VS Code rendering timings.
const {spawn}=require('node:child_process');
const assert=require('node:assert/strict');
const {pathToFileURL}=require('node:url');
const path=require('node:path');
const child=spawn(process.argv[2]||'dart',['run','bin/quds.dart','lsp'],{stdio:['pipe','pipe','pipe']});
let buffer=Buffer.alloc(0), id=0, stderr='';
const pending=new Map(), diagnostics=new Map(), waiting=new Map();
child.stderr.on('data', b=>stderr+=b);
function fail(error){for(const p of pending.values())p.reject(error);pending.clear();for(const p of waiting.values())p.reject(error);waiting.clear();}
child.on('error',fail);
child.on('exit',code=>fail(new Error(`server exited ${code}: ${stderr}`)));
child.stdout.on('data', chunk=>{
 buffer=Buffer.concat([buffer,chunk]);
 while(true){
  const end=buffer.indexOf('\r\n\r\n');if(end<0)return;
  const length=Number(/Content-Length: (\d+)/i.exec(buffer.subarray(0,end).toString())[1]);
  if(buffer.length<end+4+length)return;
  const message=JSON.parse(buffer.subarray(end+4,end+4+length).toString());
  buffer=buffer.subarray(end+4+length);
  if(message.method==='textDocument/publishDiagnostics' && message.params.qudsAnalysisComplete!==false){
   diagnostics.set(message.params.version,message.params);
   const p=waiting.get(message.params.version);if(p){waiting.delete(message.params.version);p.resolve(message.params);}
  }else if(pending.has(message.id)){
   const p=pending.get(message.id);pending.delete(message.id);
   if(message.error)p.reject(new Error(message.error.message));else p.resolve(message.result);
  }
 }
});
function send(message){const json=JSON.stringify({jsonrpc:'2.0',...message});child.stdin.write(`Content-Length: ${Buffer.byteLength(json)}\r\n\r\n${json}`);}
function request(method,params){return new Promise((resolve,reject)=>{const current=++id;pending.set(current,{resolve,reject});send({id:current,method,params});});}
function ready(version){if(diagnostics.has(version))return Promise.resolve(diagnostics.get(version));return new Promise((resolve,reject)=>waiting.set(version,{resolve,reject}));}
const timeout=setTimeout(()=>{console.error('LSP growth timed out',stderr);child.kill();process.exitCode=1;},60000);
(async()=>{
 await request('initialize',{});
 const uri=pathToFileURL(path.resolve('test/editor_wire_growth.quds')).toString();
 let source='main():\n'+Array.from({length:5000},(_,i)=>`  value${i} = ${i}\n  print value${i}\n`).join('');
 send({method:'textDocument/didOpen',params:{textDocument:{uri,version:1,text:source}}});
 await ready(1);
 const samples=[];
 for(let i=0;i<10;i++){
  const start=performance.now();
  const tokens=request('textDocument/semanticTokens/full',{textDocument:{uri}});
  const completion=request('textDocument/completion',{textDocument:{uri},position:{line:10000,character:8}});
  const [t,c]=await Promise.all([tokens,completion]);
  assert.equal(t.data.length,15001*5);
  assert(c.items.some(i=>i.label==='value4999'));
  samples.push(performance.now()-start);
 }
 let recoveryMs;
 for(let version=2;version<=4;version++){
  const edited=source+`  values${version} = [${version}]\n  print values${version}.\n`;
  const start=performance.now();
  send({method:'textDocument/didChange',params:{textDocument:{uri,version},contentChanges:[{text:edited}]}});
  const d=await ready(version);assert(d.diagnostics.length>0);
  const lines=edited.split('\n'),line=lines.length-2;
  const c=await request('textDocument/completion',{textDocument:{uri},position:{line,character:lines[line].length}});
  assert(c.items.some(i=>i.label==='length'));
  assert(c.items.some(i=>i.label==='add'));
  recoveryMs=performance.now()-start;
  source=edited.replace(`values${version}.\n`,`values${version}.length\n`);
 }
 samples.sort((a,b)=>a-b);
 console.log(JSON.stringify({schema:1,bindings:5000,lines:10002,samples:10,
  pipeline_p50_ms:samples[4],pipeline_p95_ms:samples[9],last_edit_ready_and_completion_ms:recoveryMs,
  scope:'real stdio, semantic request then completion, includes framing and JSON decoding; excludes VS Code rendering'},null,2));
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>{clearTimeout(timeout);child.kill();});
