const fs=require('node:fs'), vm=require('node:vm'), assert=require('node:assert/strict');
let now=0,id=0;const timers=new Map();
function setTimer(fn,delay){const current=++id;timers.set(current,{fn,due:now+delay});return current;}
function advance(to){while(true){const next=[...timers].filter(([,v])=>v.due<=to).sort((a,b)=>a[1].due-b[1].due)[0];if(!next)break;timers.delete(next[0]);now=next[1].due;next[1].fn();}now=to;}
const fake={EventEmitter:class{constructor(){this.count=0;}fire(){this.count++;}dispose(){}},Uri:{parse(s){return s;}}};
const box={module:{exports:{}},require(n){return n==='vscode'?fake:require(n);},process,console,Buffer,setTimeout:setTimer,clearTimeout(i){timers.delete(i);},__dirname:require('node:path').resolve('editors/vscode')};
vm.runInNewContext(fs.readFileSync('editors/vscode/extension.js','utf8')+'\nmodule.exports.Client=QudsClient;',box);
const client=new box.module.exports.Client({set(){},delete(){}},{appendLine(){}});client.ready=true;
const sent=[];client.sendChange=d=>sent.push(d.version);
const uri='file:///test.quds';let doc;
for(let version=1;version<=11;version++){advance((version-1)*30);doc={languageId:'quds',version,uri:{toString(){return uri;}}};client.change(doc);}
assert(sent.length>=2,'A stream of keystrokes must flush before typing stops');
advance(400);assert.equal(sent.at(-1),11);
assert(sent.every((v,i)=>i===0||v>sent[i-1]));
assert.equal(client.timers.size,0);assert.equal(client.maximumTimers.size,0);
client.onMessage({method:'quds/semanticTokensReady',params:{uri,version:10}});
assert.equal(client.semanticRefresh.count,0);
client.onMessage({method:'quds/semanticTokensReady',params:{uri,version:11}});
assert.equal(client.semanticRefresh.count,1);
client.showDiagnostics({uri,version:11,diagnostics:[],qudsAnalysisComplete:false});
assert.equal(client.semanticRefresh.count,1);
client.showDiagnostics({uri,version:11,diagnostics:[],qudsAnalysisComplete:true});
assert.equal(client.semanticRefresh.count,2);
client.change(doc);client.close(doc);advance(1000);assert.equal(client.maximumTimers.size,0);
client.dispose();assert.equal(timers.size,0);
console.log('VSCODE DIAGNOSTICS OK');
