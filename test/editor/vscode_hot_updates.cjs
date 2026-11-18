const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const calls=[];
let saved=true;
const vscode={EventEmitter:class{fire(){}dispose(){}},debug:{activeDebugSession:{type:'quds',async customRequest(command,args){calls.push(['request',command,args.reason]);}}},workspace:{async saveAll(){calls.push(['save']);return saved;}},window:{showInformationMessage(s){calls.push(['info',s]);},showErrorMessage(s){calls.push(['error',s]);}}};
const box={module:{exports:{}},require(n){return n==='vscode'?vscode:require(n);},console,process,Buffer,setTimeout,clearTimeout,__dirname:require('node:path').resolve('editors/vscode')};
vm.runInNewContext(fs.readFileSync('editors/vscode/extension.js','utf8')+'\nmodule.exports.hotUpdate=hotUpdate;',box);
(async()=>{
 await box.module.exports.hotUpdate('hotReload');
 assert.deepEqual(calls.map(c=>c[0]),['save','request']);assert.equal(calls[1][1],'hotReload');
 calls.length=0;saved=false;await box.module.exports.hotUpdate('hotRestart');
 assert.deepEqual(calls.map(c=>c[0]),['save','error']);
 calls.length=0;vscode.debug.activeDebugSession=null;await box.module.exports.hotUpdate('hotReload');
 assert.equal(calls[0][0],'info');
 console.log('VSCODE HOT UPDATES OK');
})().catch(e=>{console.error(e);process.exitCode=1;});
