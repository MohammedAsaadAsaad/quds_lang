const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const fake = {
  EventEmitter: class { fire() {} dispose() {} },
  SignatureHelp: class {},
  SignatureInformation: class { constructor(label) { this.label=label; } },
  ParameterInformation: class { constructor(label) { this.label=label; } },
};
const filename='editors/vscode/extension.js';
const source=fs.readFileSync(filename,'utf8');
const box={module:{exports:{}}, require(name) { return name==='vscode' ? fake : require(name); }, console,process,Buffer,setTimeout,clearTimeout,__dirname:require('node:path').resolve('editors/vscode')};
vm.runInNewContext(source+'\nmodule.exports.ClientForTest=QudsClient;',box,{filename});
(async()=>{
  const client=new box.module.exports.ClientForTest({}, {appendLine(){}});
  client.sync=async()=>{};
  client.request=async(command)=>{
    assert.equal(command,'textDocument/signatureHelp');
    return {signatures:[{label:'sum(a: int, b: int)',parameters:[{label:'a: int'},{label:'b: int'}]}],activeSignature:0,activeParameter:1};
  };
  const doc={uri:{toString(){return 'file:///test.quds';}}};
  const result=await client.signatureHelp(doc,{line:0,character:4},{isCancellationRequested:false});
  assert.equal(result.activeParameter,1);
  assert.equal(result.signatures[0].parameters[1].label,'b: int');
  assert.equal(await client.signatureHelp(doc,{line:0,character:4},{isCancellationRequested:true}),undefined);
  console.log('VSCODE SIGNATURE OK');
})().catch(e=>{console.error(e);process.exitCode=1;});
