const {spawn}=require('node:child_process');
const assert=require('node:assert/strict');
const child=spawn(process.argv[2],[process.argv[3],'debug'],{stdio:['pipe','pipe','pipe']});
const program=process.argv[4];
let bytes=Buffer.alloc(0),seq=0,stderr='',output='';
const pending=new Map(),seen=new Map(),waiters=new Map();
function fail(e){for(const p of pending.values())p.reject(e);pending.clear();for(const q of waiters.values())for(const p of q)p.reject(e);waiters.clear();}
child.on('error',fail);child.stderr.on('data',b=>stderr+=b);child.on('exit',c=>fail(new Error(`DAP exited ${c}: ${stderr}`)));
child.stdout.on('data',b=>{bytes=Buffer.concat([bytes,b]);while(true){const end=bytes.indexOf('\r\n\r\n');if(end<0)return;const n=Number(/Content-Length: (\d+)/i.exec(bytes.subarray(0,end).toString())[1]);if(bytes.length<end+4+n)return;const m=JSON.parse(bytes.subarray(end+4,end+4+n).toString());bytes=bytes.subarray(end+4+n);if(m.type==='response'){const p=pending.get(m.request_seq);if(p){pending.delete(m.request_seq);m.success===false?p.reject(new Error(m.message||JSON.stringify(m))):p.resolve(m);}}else if(m.type==='event'){if(m.event==='output')output+=m.body?.output||'';const q=waiters.get(m.event);if(q?.length)q.shift().resolve(m);else{if(!seen.has(m.event))seen.set(m.event,[]);seen.get(m.event).push(m);}}}});
function request(command,args={}){return new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});const json=JSON.stringify({seq:id,type:'request',command,arguments:args});child.stdin.write(`Content-Length: ${Buffer.byteLength(json)}\r\n\r\n${json}`);});}
function event(name){const q=seen.get(name);if(q?.length)return Promise.resolve(q.shift());return new Promise((resolve,reject)=>{if(!waiters.has(name))waiters.set(name,[]);waiters.get(name).push({resolve,reject});});}
const timer=setTimeout(()=>{console.error('DAP timed out',stderr,output);child.kill();process.exitCode=1;},70000);
(async()=>{
 await request('initialize',{adapterID:'quds',clientID:'export-repro',linesStartAt1:true,columnsStartAt1:true,pathFormat:'path'});
 await event('initialized');
 await request('setBreakpoints',{source:{path:program},breakpoints:[{line:5}]});
 await request('configurationDone');
 await request('launch',{program,stopOnEntry:false});
 const stopped=await event('stopped');
 const stack=await request('stackTrace',{threadId:stopped.body.threadId});
 assert(stack.body.stackFrames.some(f=>f.source?.path===program&&f.line===5));
 await request('continue',{threadId:stopped.body.threadId});
 await event('terminated');
 assert(output.includes('test_lang_quds'),output);
 assert(!output.includes('No such file or directory'),output);
 await request('disconnect');
 console.log('EXPORT DEBUG OK');
})().catch(e=>{console.error(e,stderr,output);process.exitCode=1;}).finally(()=>{clearTimeout(timer);child.kill();});
