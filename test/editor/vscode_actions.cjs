const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { fileURLToPath, pathToFileURL } = require('node:url');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'quds-editor-actions-'));
try {
  const compiler = path.join(root, 'compiler قدس');
  const app = path.join(root, 'my-app');
  fs.mkdirSync(path.join(compiler,'bin'), {recursive:true});
  fs.mkdirSync(path.join(compiler,'lib'), {recursive:true});
  fs.mkdirSync(path.join(app,'.dart_tool'), {recursive:true});
  fs.writeFileSync(path.join(compiler,'pubspec.yaml'), 'name: quds\n');
  fs.mkdirSync(path.join(compiler,'bin'), {recursive:true});
  fs.writeFileSync(path.join(compiler,'bin/quds.dart'), '// compiler\n');
  fs.writeFileSync(path.join(compiler,'lib/parser.dart'), '// parser\n');
  fs.writeFileSync(path.join(app,'pubspec.yaml'), 'name: academy\n');
  const config = path.join(app,'.dart_tool/package_config.json');
  const save = (rootUri) => fs.writeFileSync(config,JSON.stringify({configVersion:2,packages:[{name:'quds', rootUri, packageUri:'lib/'}]}));
  save(pathToFileURL(compiler+path.sep).href);
  const sent = [];
  const terminals = [];
  const fake = {
    env: { shell: '' },
    workspace:{
      workspaceFolders:[{uri:{fsPath:app}}],
      getConfiguration(){return{get(){return undefined;}};},
      async openTextDocument(uri){return { uri, isDirty: false, async save(){} };},
    },
    window: {
      terminals,
      createTerminal(options){
        const term = {
          name: options.name,
          creationOptions: options,
          shown: false,
          show(){ this.shown = true; },
          sendText(text){ sent.push(text); },
        };
        terminals.push(term);
        return term;
      },
      showErrorMessage(message){ throw new Error(message); },
    },
    EventEmitter:class {constructor(){this.count=0;} fire(){this.count++;} dispose(){}},
    CodeLens:class {constructor(range, command){this.range=range;this.command=command;}},
    Range:class {}, Uri:{parse(s){return typeof s === 'string' && s.startsWith('file:') ? { scheme: 'file', fsPath: fileURLToPath(s) } : s;}}
  };
  const box={module:{exports:{}},require(n){return n==='vscode'?fake:require(n);},console,process,Buffer,setTimeout,clearTimeout,__dirname:path.resolve('editors/vscode')};
  vm.runInNewContext(fs.readFileSync('editors/vscode/extension.js','utf8')+
    '\nmodule.exports.test={packageRoot,serverCommand,QudsClient,formatTerminalCommand,cliBinary,runTool};',box);
  const {packageRoot,serverCommand,QudsClient,formatTerminalCommand,cliBinary,runTool}=box.module.exports.test;
  assert.equal(path.resolve(packageRoot(app)), compiler);
  const relative = path.relative(path.dirname(config), compiler).split(path.sep).join('/')+'/';
  save(encodeURI(relative));
  assert.equal(path.resolve(packageRoot(path.join(app,'lib'))), compiler);
  const binary=cliBinary(compiler);
  assert.equal(path.basename(cliBinary(compiler, 'win32')), 'quds.exe');
  assert.equal(path.basename(cliBinary(compiler, 'linux')), 'quds');
  const winCmd = [
    'C:\\Users\\mohammed\\AppData\\Local\\Pub\\Cache\\bin\\quds.bat',
    'run',
    'd:\\test_quds_lang\\test_lang\\main.quds',
  ];
  assert.equal(
    formatTerminalCommand(winCmd, {
      platform: 'win32',
      shell: 'C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    }),
    "& 'C:\\Users\\mohammed\\AppData\\Local\\Pub\\Cache\\bin\\quds.bat' 'run' 'd:\\test_quds_lang\\test_lang\\main.quds'",
  );
  assert.equal(
    formatTerminalCommand(
      ['C:\\Users\\O\'Brien\\quds.bat', 'run', 'd:\\my app\\main.quds'],
      { platform: 'win32', shell: '' },
    ),
    "& 'C:\\Users\\O''Brien\\quds.bat' 'run' 'd:\\my app\\main.quds'",
  );
  assert.equal(
    formatTerminalCommand(winCmd, {
      platform: 'win32',
      shell: 'C:\\Program Files\\PowerShell\\7\\pwsh.exe',
    }),
    "& 'C:\\Users\\mohammed\\AppData\\Local\\Pub\\Cache\\bin\\quds.bat' 'run' 'd:\\test_quds_lang\\test_lang\\main.quds'",
  );
  assert.equal(
    formatTerminalCommand(winCmd, {
      platform: 'win32',
      shell: 'C:\\WINDOWS\\system32\\cmd.exe',
    }),
    '"C:\\Users\\mohammed\\AppData\\Local\\Pub\\Cache\\bin\\quds.bat" "run" "d:\\test_quds_lang\\test_lang\\main.quds"',
  );
  assert.equal(
    formatTerminalCommand(winCmd, {
      platform: 'win32',
      shell: 'C:\\Program Files\\Git\\bin\\bash.exe',
    }),
    "'C:\\Users\\mohammed\\AppData\\Local\\Pub\\Cache\\bin\\quds.bat' 'run' 'd:\\test_quds_lang\\test_lang\\main.quds'",
  );
  assert.equal(
    formatTerminalCommand(['/usr/local/bin/quds', 'run', "/tmp/o'brien/main.quds"], {
      platform: 'linux',
      shell: '/bin/bash',
    }),
    "'/usr/local/bin/quds' 'run' '/tmp/o'\\''brien/main.quds'",
  );
  fs.mkdirSync(path.dirname(binary),{recursive:true});fs.writeFileSync(binary,'old binary');
  fs.utimesSync(binary,new Date(2000,0,1),new Date(2000,0,1));
  const stale=serverCommand(path.join(app,'lib/main.quds'));
  assert.equal(stale.command[1],'run');
  assert.equal(stale.command[2],path.join(compiler,'bin/quds.dart'));
  assert.equal(stale.rebuild,true);
  fs.utimesSync(binary,new Date(2035,0,1),new Date(2035,0,1));
  assert.equal(serverCommand(path.join(app,'lib/main.quds')).command[0],binary);
  const runFile = path.join(app, 'lib', 'main.quds');
  fs.mkdirSync(path.dirname(runFile), { recursive: true });
  fs.writeFileSync(runFile, 'main():\n  print 1\n');
  (async()=>{
    try {
      fake.env.shell = 'C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
      await runTool('run', pathToFileURL(runFile).href);
      assert.equal(sent.length, 1);
      assert.ok(sent[0].startsWith("& '"), `expected PowerShell call operator, got: ${sent[0]}`);
      assert.ok(sent[0].includes("'run'"));
      terminals[0].creationOptions = { shellPath: 'C:\\WINDOWS\\system32\\cmd.exe' };
      await runTool('run', pathToFileURL(runFile).href);
      assert.equal(sent.length, 2);
      assert.ok(sent[1].startsWith('"'), `expected cmd.exe double-quoted command, got: ${sent[1]}`);
      assert.ok(sent[1].includes('"run"'));
      fs.writeFileSync(config,'invalid JSON');
      assert.equal(packageRoot(app),null);
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
    } finally {
      fs.rmSync(root,{recursive:true,force:true});
    }
  })().catch(e=>{console.error(e);process.exitCode=1;});
} catch (e) {
  fs.rmSync(root,{recursive:true,force:true});
  throw e;
}
