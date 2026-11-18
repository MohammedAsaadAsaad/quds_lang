const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { pathToFileURL } = require('node:url');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'quds-editor-actions-'));
try {
  const compiler = path.join(root, 'compiler قدس');
  const app = path.join(root, 'my-app');
  fs.mkdirSync(path.join(compiler,'bin'), {recursive:true});
  fs.mkdirSync(path.join(compiler,'lib'), {recursive:true});
  fs.mkdirSync(path.join(app,'.dart_tool'), {recursive:true});
  fs.writeFileSync(path.join(compiler,'pubspec.yaml'), 'name: quds_lang\n');
  fs.writeFileSync(path.join(compiler,'bin/quds.dart'), '// compiler\n');
  fs.writeFileSync(path.join(compiler,'lib/parser.dart'), '// parser\n');
  fs.writeFileSync(path.join(app,'pubspec.yaml'), 'name: academy\n');
  const config = path.join(app,'.dart_tool/package_config.json');
  const save = (rootUri) => fs.writeFileSync(config,JSON.stringify({configVersion:2,packages:[{name:'quds_lang', rootUri, packageUri:'lib/'}]}));
  save(pathToFileURL(compiler+path.sep).href);
  const fake = {
    workspace:{workspaceFolders:[{uri:{fsPath:app}}], getConfiguration(){return{get(){return undefined;}};}},
    EventEmitter:class {constructor(){this.count=0;} fire(){this.count++;} dispose(){}},
    CodeLens:class {constructor(range, command){this.range=range;this.command=command;}},
    Range:class {}, Uri:{parse(s){return s;}}
  };
  const box={module:{exports:{}},require(n){return n==='vscode'?fake:require(n);},console,process,Buffer,setTimeout,clearTimeout,__dirname:path.resolve('editors/vscode')};
  vm.runInNewContext(fs.readFileSync('editors/vscode/extension.js','utf8')+
    '\nmodule.exports.test={packageRoot,serverCommand,QudsClient};',box);
  const {packageRoot,serverCommand,QudsClient}=box.module.exports.test;
  assert.equal(path.resolve(packageRoot(app)), compiler);
  const relative = path.relative(path.dirname(config), compiler).split(path.sep).join('/')+'/';
  save(encodeURI(relative));
  assert.equal(path.resolve(packageRoot(path.join(app,'lib'))), compiler);
  const binary=path.join(compiler,'.dart_tool/quds/quds');
  fs.mkdirSync(path.dirname(binary),{recursive:true});fs.writeFileSync(binary,'old binary');
  fs.utimesSync(binary,new Date(2000,0,1),new Date(2000,0,1));
  const stale=serverCommand(path.join(app,'lib/main.quds'));
  assert.equal(stale.command[1],'run');
  assert.equal(stale.command[2],path.join(compiler,'bin/quds.dart'));
  assert.equal(stale.rebuild,true);
  fs.utimesSync(binary,new Date(2035,0,1),new Date(2035,0,1));
  assert.equal(serverCommand(path.join(app,'lib/main.quds')).command[0],binary);
  fs.writeFileSync(config,'invalid JSON');
  assert.equal(packageRoot(app),null);
  (async()=>{
    const client=new QudsClient({set(){}},{appendLine(){}});
    client.sync=async()=>{};
    let resolve;
    client.request=()=>new Promise(r=>{resolve=r;});
    const document={version:1,uri:{toString(){return 'file:///main.quds';}}};
    const pending=client.codeLenses(document);
    await new Promise(setImmediate);
    document.version=2;
    resolve([{range:{start:{line:0,character:0},end:{line:0,character:4}}, command:{title:'Run',command:'quds.run'}}]);
    assert.equal((await pending).length,0);
    client.dispose();
    console.log('VSCODE ACTIONS OK');
  })().catch(e=>{console.error(e);process.exitCode=1;});
} finally {fs.rmSync(root,{recursive:true,force:true});}
