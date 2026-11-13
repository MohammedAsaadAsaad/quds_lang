const vscode = require('vscode');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const languageId = 'quds';

function activate(context) {
  const diagnostics = vscode.languages.createDiagnosticCollection(languageId);
  const output = vscode.window.createOutputChannel('Quds');
  const client = new QudsClient(diagnostics, output);
  context.subscriptions.push(
    diagnostics,
    output,
    client,
    vscode.languages.registerDocumentFormattingEditProvider(languageId, {
      provideDocumentFormattingEdits(document, options) {
        return client.format(document, options);
      },
    }),
    vscode.languages.registerHoverProvider(languageId, {
      provideHover(document, position, token) {
        return client.hover(document, position, token);
      },
    }),
    vscode.languages.registerDefinitionProvider(languageId, {
      provideDefinition(document, position, token) {
        return client.definition(document, position, token);
      },
    }),
    vscode.languages.registerCompletionItemProvider(
      languageId,
      {
        provideCompletionItems(document, position, token) {
          return client.complete(document, position, token);
        },
      },
      '.',
      ':',
      '/',
    ),
    vscode.languages.registerCodeLensProvider(languageId, {
      provideCodeLenses(document) {
        return client.codeLenses(document);
      },
    }),
    vscode.languages.registerDocumentSemanticTokensProvider(
      languageId,
      {
        provideDocumentSemanticTokens(document) {
          return client.semanticTokens(document);
        },
      },
      new vscode.SemanticTokensLegend(
        ['function', 'method', 'property', 'variable', 'parameter', 'class'],
        ['declaration', 'readonly'],
      ),
    ),
    vscode.commands.registerCommand('quds.run', (uri) => runTool('run', uri)),
    vscode.commands.registerCommand('quds.debug', (uri) => debugProgram(uri)),
    vscode.commands.registerCommand('quds.showDart', (uri) => showDart(uri)),
    vscode.commands.registerCommand('quds.profile', (uri) =>
      runTool('benchmark', uri),
    ),
    vscode.workspace.onDidOpenTextDocument((document) => client.open(document)),
    vscode.workspace.onDidChangeTextDocument((event) =>
      client.change(event.document),
    ),
    vscode.workspace.onDidCloseTextDocument((document) =>
      client.close(document),
    ),
    vscode.commands.registerCommand('quds.restartServer', () => client.restart()),
    vscode.debug.registerDebugConfigurationProvider('quds', {
      async resolveDebugConfiguration(_folder, config) {
        const empty = !config.type && !config.request && !config.name;
        const editor = vscode.window.activeTextEditor;
        const open =
          editor && editor.document.languageId === languageId
            ? editor.document.uri.fsPath
            : '';
        if (empty) {
          if (!open) return undefined;
          config.type = 'quds';
          config.name = 'Debug Quds';
          config.request = 'launch';
          config.program = open;
        }
        if (!config.program && open) config.program = open;
        if (config.program && !config.cwd) config.cwd = path.dirname(config.program);
        await applySelectedDevice(config);
        return config;
      },
    }),
    vscode.debug.registerDebugAdapterDescriptorFactory('quds', {
      createDebugAdapterDescriptor(session) {
        const program = session.configuration.program;
        const spec = launchSpec(
          typeof program === 'string' && program ? program : process.cwd(),
          'debug',
        );
        if (!spec) {
          throw new Error('Quds could not find dart or the quds command.');
        }
        const windowsScript = process.platform === 'win32' &&
          /\.(bat|cmd)$/i.test(spec.command[0]);
        const executable = windowsScript ? 'cmd.exe' : spec.command[0];
        const args = windowsScript
          ? ['/c', ...spec.command]
          : spec.command.slice(1);
        return new vscode.DebugAdapterExecutable(executable, args, {
          cwd: spec.cwd,
          env: spec.env,
        });
      },
    }),
  );
  for (const document of vscode.workspace.textDocuments) {
    client.open(document);
  }
  client.start();
}

function completionItem(entry) {
  const kind = Math.max(0, Number(entry.kind || 1) - 1);
  const item = new vscode.CompletionItem(entry.label, kind);
  if (entry.detail) item.detail = entry.detail;
  if (entry.filterText) item.filterText = entry.filterText;
  if (entry.sortText) item.sortText = entry.sortText;
  if (entry.commitCharacters) item.commitCharacters = entry.commitCharacters;
  const command = entry.command;
  if (command && command.command) {
    item.command = {
      command: String(command.command),
      title: String(command.title || ''),
      arguments: command.arguments,
    };
  }
  const edit = entry.textEdit;
  if (edit && edit.range) {
    item.range = new vscode.Range(
      edit.range.start.line,
      edit.range.start.character,
      edit.range.end.line,
      edit.range.end.character,
    );
  }
  const text = edit && edit.newText ? edit.newText : entry.insertText;
  if (entry.insertTextFormat === 2 && text) item.insertText = new vscode.SnippetString(text);
  else if (text) item.insertText = text;
  return item;
}

function deactivate() {}

function serverCommand(documentPath) {
  const configured = vscode.workspace.getConfiguration(languageId).get('serverCommand');
  if (Array.isArray(configured) && configured.length > 0) {
    return { command: configured.map(String), cwd: undefined, env: process.env };
  }
  const starts = [];
  for (const folder of vscode.workspace.workspaceFolders ?? []) {
    starts.push(folder.uri.fsPath);
  }
  if (documentPath) starts.push(path.dirname(documentPath));
  const dart = resolveDart();
  for (const start of starts) {
    const root = packageRoot(start);
    if (!root || !dart) continue;
    return {
      command: [dart, 'run', path.join(root, 'bin', 'quds.dart'), 'lsp'],
      cwd: root,
      env: toolEnv(dart),
    };
  }
  const quds = resolveQuds();
  if (quds && dart) {
    return { command: [quds, 'lsp'], cwd: undefined, env: toolEnv(dart) };
  }
  return { command: [quds || 'quds', 'lsp'], cwd: undefined, env: process.env };
}

function pathSeparator() {
  return process.platform === 'win32' ? ';' : ':';
}

function pathDirs() {
  return (process.env.PATH || '').split(pathSeparator()).filter(Boolean);
}

function homeDir() {
  if (process.platform === 'win32') {
    return process.env.USERPROFILE || process.env.HOME || '';
  }
  return process.env.HOME || process.env.USERPROFILE || '';
}

function pubCacheBin() {
  if (process.env.PUB_CACHE) return path.join(process.env.PUB_CACHE, 'bin');
  if (process.platform === 'win32') {
    const local = process.env.LOCALAPPDATA ||
      (homeDir() ? path.join(homeDir(), 'AppData', 'Local') : '');
    return local ? path.join(local, 'Pub', 'Cache', 'bin') : '';
  }
  const home = homeDir();
  return home ? path.join(home, '.pub-cache', 'bin') : '';
}

function namedExecutable(dir, name) {
  const names = process.platform === 'win32'
    ? [`${name}.exe`, `${name}.bat`, `${name}.cmd`, name]
    : [name];
  for (const file of names) {
    const candidate = path.join(dir, file);
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

function resolveDart() {
  for (const dir of pathDirs()) {
    const found = namedExecutable(dir, 'dart');
    if (found) return found;
  }
  const home = homeDir();
  const flutterRoot = process.env.FLUTTER_ROOT || '';
  const extras = [
    flutterRoot ? path.join(flutterRoot, 'bin') : '',
    home ? path.join(home, 'development', 'flutter', 'bin') : '',
    home ? path.join(home, 'flutter', 'bin') : '',
    home ? path.join(home, 'snap', 'flutter', 'common', 'flutter', 'bin') : '',
    '/usr/lib/dart/bin',
    '/usr/bin',
  ];
  for (const dir of extras) {
    if (!dir) continue;
    const found = namedExecutable(dir, 'dart');
    if (found) return found;
  }
  return null;
}

function resolveQuds() {
  for (const dir of pathDirs()) {
    const found = namedExecutable(dir, 'quds');
    if (found) return found;
  }
  const pub = pubCacheBin();
  return pub ? namedExecutable(pub, 'quds') : null;
}

function packageRoot(start) {
  let dir = start;
  const seen = new Set();
  while (dir && !seen.has(dir)) {
    seen.add(dir);
    const bin = path.join(dir, 'bin', 'quds.dart');
    const pubspec = path.join(dir, 'pubspec.yaml');
    if (fs.existsSync(bin) && fs.existsSync(pubspec)) {
      const text = fs.readFileSync(pubspec, 'utf8');
      if (/^name:\s*quds_lang\s*$/m.test(text)) return dir;
    }
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

function toolEnv(dart) {
  const sep = pathSeparator();
  const prefix = [path.dirname(dart), pubCacheBin()].filter(Boolean).join(sep);
  const current = process.env.PATH || '';
  return { ...process.env, PATH: current ? `${prefix}${sep}${current}` : prefix };
}

function spawnCommand(command, options) {
  const script = process.platform === 'win32' && /\.(bat|cmd)$/i.test(command[0]);
  return spawn(command[0], command.slice(1), script ? { ...options, shell: true } : options);
}

function quote(value) {
  return `'${String(value).replaceAll("'", `'\\''`)}'`;
}

function launchSpec(file, verb) {
  const dart = resolveDart();
  const root = packageRoot(path.dirname(file));
  if (root && dart) {
    return {
      command: [dart, 'run', path.join(root, 'bin', 'quds.dart'), verb, file],
      cwd: root,
      env: toolEnv(dart),
    };
  }
  const quds = resolveQuds();
  if (quds && dart) {
    return { command: [quds, verb, file], cwd: path.dirname(file), env: toolEnv(dart) };
  }
  return null;
}

function execSpec(spec) {
  return new Promise((resolve) => {
    const child = spawnCommand(spec.command, {
      cwd: spec.cwd,
      env: spec.env,
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });
    child.on('error', (error) => resolve({ code: 1, stdout, stderr: error.message }));
    child.on('exit', (code) => resolve({ code: code ?? 1, stdout, stderr }));
  });
}

async function runTool(verb, uriArgument) {
  const uri = targetUri(uriArgument);
  if (!uri || uri.scheme !== 'file') return;
  const document = await vscode.workspace.openTextDocument(uri);
  if (document.isDirty) await document.save();
  const spec = launchSpec(uri.fsPath, verb);
  if (!spec) {
    vscode.window.showErrorMessage('Quds could not find dart or the quds command.');
    return;
  }
  let terminal = vscode.window.terminals.find((item) => item.name === 'Quds');
  if (!terminal) {
    terminal = vscode.window.createTerminal({ name: 'Quds', cwd: spec.cwd, env: spec.env });
  }
  terminal.show();
  terminal.sendText(spec.command.map(quote).join(' '));
}

async function debugProgram(uriArgument) {
  const uri = targetUri(uriArgument);
  if (!uri || uri.scheme !== 'file') return;
  const document = await vscode.workspace.openTextDocument(uri);
  if (document.isDirty) await document.save();
  const file = uri.fsPath;
  const folder = vscode.workspace.getWorkspaceFolder(uri);
  const config = {
    type: 'quds',
    name: 'Debug Quds',
    request: 'launch',
    program: file,
    cwd: path.dirname(file),
  };
  await applySelectedDevice(config);
  let started = false;
  try {
    started = await vscode.debug.startDebugging(folder, config);
  } catch (error) {
    started = false;
  }
  if (!started) {
    vscode.window.showErrorMessage('Quds could not start the debugger.');
  }
}

async function applySelectedDevice(config) {
  if (config.deviceId) return;
  let deviceId = null;
  try {
    deviceId = await vscode.commands.executeCommand('flutter.getSelectedDeviceId');
  } catch (error) {
    deviceId = null;
  }
  if (typeof deviceId !== 'string' || !deviceId) return;
  config.deviceId = deviceId;
  const args = Array.isArray(config.toolArgs) ? config.toolArgs.map(String) : [];
  if (!args.includes('-d') && !args.includes('--device-id')) {
    args.push('-d', deviceId);
  }
  config.toolArgs = args;
}

function packageRootOf(file) {
  let dir = path.dirname(file);
  const start = dir;
  const seen = new Set();
  while (dir && !seen.has(dir)) {
    seen.add(dir);
    if (
      fs.existsSync(path.join(dir, 'pubspec.yaml')) ||
      fs.existsSync(path.join(dir, 'quds.yaml'))
    ) {
      return dir;
    }
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return start;
}

function outputDart(file) {
  const root = packageRootOf(file);
  const relative = path.relative(root, file).replace(/\.quds$/, '.dart');
  return path.join(root, '.dart_tool', 'quds', 'out', relative);
}

async function showDart(uriArgument) {
  const uri = targetUri(uriArgument);
  if (!uri || uri.scheme !== 'file') return;
  const document = await vscode.workspace.openTextDocument(uri);
  if (document.isDirty) await document.save();
  const file = uri.fsPath;
  const spec = launchSpec(file, 'build');
  if (!spec) {
    vscode.window.showErrorMessage('Quds could not find dart or the quds command.');
    return;
  }
  const built = await execSpec(spec);
  if (built.code !== 0) {
    const detail = `${built.stderr}${built.stdout}`.trim();
    vscode.window.showErrorMessage(detail || 'Quds build failed.');
    return;
  }
  const dartFile = outputDart(file);
  await vscode.commands.executeCommand(
    'vscode.diff',
    uri,
    vscode.Uri.file(dartFile),
    `${path.basename(file)} ↔ ${path.basename(dartFile)}`,
  );
}

function targetUri(uriArgument) {
  if (typeof uriArgument === 'string') return vscode.Uri.parse(uriArgument);
  const editor = vscode.window.activeTextEditor;
  if (!editor || editor.document.languageId !== languageId) {
    vscode.window.showErrorMessage('Open a .quds file first.');
    return null;
  }
  return editor.document.uri;
}

class QudsClient {
  constructor(diagnostics, output) {
    this.diagnostics = diagnostics;
    this.output = output;
    this.pending = new Map();
    this.nextId = 1;
    this.buffer = Buffer.alloc(0);
    this.documents = new Map();
    this.synced = new Map();
    this.timers = new Map();
    this.child = null;
    this.ready = false;
    this.starting = null;
  }

  start() {
    if (this.starting) return this.starting;
    const sample = [...this.documents.values()][0];
    const { command, cwd, env } = serverCommand(sample && sample.uri.fsPath);
    this.output.appendLine(`Starting ${command.join(' ')}`);
    this.buffer = Buffer.alloc(0);
    const child = spawnCommand(command, {
      cwd,
      env,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    this.child = child;
    child.stdout.on('data', (chunk) => {
      if (this.child !== child) return;
      this.onData(chunk);
    });
    child.stderr.on('data', (chunk) => this.output.append(chunk.toString()));
    child.on('error', (error) => {
      if (this.child !== child) return;
      this.output.appendLine(error.message);
      vscode.window.showErrorMessage(`Quds language server failed to start: ${error.message}`);
    });
    child.on('exit', (code, signal) => {
      if (this.child !== child) return;
      const detail = code === null ? signal || 'null' : code;
      this.output.appendLine(`Language server exited (${detail})`);
      this.failPending(`Language server exited (${detail})`);
      this.child = null;
      this.ready = false;
      this.starting = null;
    });
    this.starting = this.request('initialize', {
      processId: process.pid,
      capabilities: {
          textDocument: {
            synchronization: { dynamicRegistration: false },
            formatting: { dynamicRegistration: false },
            hover: { dynamicRegistration: false },
            codeLens: { dynamicRegistration: false },
            semanticTokens: { dynamicRegistration: false },
            publishDiagnostics: {},
          },
      },
    })
      .then(() => {
        this.ready = true;
        this.notify('initialized', {});
        for (const document of this.documents.values()) this.sendOpen(document);
      })
      .catch((error) => {
        if (child.qudsReplaced) return;
        vscode.window.showErrorMessage(`Quds language server failed to start: ${error.message}`);
        throw error;
      });
    return this.starting;
  }

  async restart() {
    this.stop();
    await this.start();
  }

  stop() {
    const child = this.child;
    this.child = null;
    this.ready = false;
    this.starting = null;
    this.failPending('Language server stopped');
    if (child) {
      child.qudsReplaced = true;
      child.removeAllListeners('exit');
      child.kill();
    }
  }

  dispose() {
    for (const timer of this.timers.values()) clearTimeout(timer);
    this.stop();
  }

  open(document) {
    if (document.languageId !== languageId) return;
    this.documents.set(document.uri.toString(), document);
    if (this.ready) this.sendOpen(document);
  }

  change(document) {
    if (document.languageId !== languageId) return;
    this.documents.set(document.uri.toString(), document);
    const uri = document.uri.toString();
    const previous = this.timers.get(uri);
    if (previous) clearTimeout(previous);
    this.timers.set(
      uri,
      setTimeout(() => {
        this.timers.delete(uri);
        if (this.ready) this.sendChange(document);
      }, 200),
    );
  }

  close(document) {
    if (document.languageId !== languageId) return;
    const uri = document.uri.toString();
    this.documents.delete(uri);
    this.synced.delete(uri);
    const timer = this.timers.get(uri);
    if (timer) clearTimeout(timer);
    this.timers.delete(uri);
    this.diagnostics.delete(document.uri);
    if (this.ready) {
      this.notify('textDocument/didClose', { textDocument: { uri } });
    }
  }

  async complete(document, position, token) {
    try {
      await this.sync(document);
      if (token && token.isCancellationRequested) return undefined;
      const result = await this.request('textDocument/completion', {
        textDocument: { uri: document.uri.toString() },
        position: { line: position.line, character: position.character },
      });
      if (token && token.isCancellationRequested) return undefined;
      const raw = result && Array.isArray(result.items) ? result.items : [];
      const items = raw.map((entry) => completionItem(entry));
      return new vscode.CompletionList(items, !!(result && result.isIncomplete));
    } catch (error) {
      this.output.appendLine(error.message);
      return undefined;
    }
  }

  async definition(document, position, token) {
    try {
      await this.sync(document);
      if (token && token.isCancellationRequested) return undefined;
      const result = await this.request('textDocument/definition', {
        textDocument: { uri: document.uri.toString() },
        position: { line: position.line, character: position.character },
      });
      if (token && token.isCancellationRequested) return undefined;
      const range = result && result.range;
      if (!result || !result.uri || !range || !range.start || !range.end) {
        return undefined;
      }
      return new vscode.Location(
        vscode.Uri.parse(result.uri),
        new vscode.Range(
          range.start.line,
          range.start.character,
          range.end.line,
          range.end.character,
        ),
      );
    } catch (error) {
      this.output.appendLine(error.message);
      return undefined;
    }
  }

  async hover(document, position, token) {
    try {
      await this.sync(document);
      if (token && token.isCancellationRequested) return undefined;
      const result = await this.request('textDocument/hover', {
        textDocument: { uri: document.uri.toString() },
        position: { line: position.line, character: position.character },
      });
      if (token && token.isCancellationRequested) return undefined;
      const contents = result && result.contents;
      const value = typeof contents === 'string' ? contents : contents && contents.value;
      if (!value) return undefined;
      const markdown = new vscode.MarkdownString();
      markdown.appendCodeblock(value, 'quds');
      return new vscode.Hover(markdown);
    } catch (error) {
      this.output.appendLine(error.message);
      return undefined;
    }
  }

  async codeLenses(document) {
    try {
      await this.sync(document);
      const lenses = await this.request('textDocument/codeLens', {
        textDocument: { uri: document.uri.toString() },
      });
      if (!Array.isArray(lenses)) return [];
      return lenses.map((lens) => {
        const command = lens.command || {};
        return new vscode.CodeLens(
          new vscode.Range(
            lens.range.start.line,
            lens.range.start.character,
            lens.range.end.line,
            lens.range.end.character,
          ),
          {
            title: command.title,
            command: command.command,
            arguments: command.arguments,
          },
        );
      });
    } catch (error) {
      this.output.appendLine(error.message);
      return [];
    }
  }

  async semanticTokens(document) {
    try {
      await this.sync(document);
      const result = await this.request('textDocument/semanticTokens/full', {
        textDocument: { uri: document.uri.toString() },
      });
      const data = result && result.data;
      if (!Array.isArray(data)) return new vscode.SemanticTokens(new Uint32Array());
      return new vscode.SemanticTokens(new Uint32Array(data));
    } catch (error) {
      this.output.appendLine(error.message);
      return new vscode.SemanticTokens(new Uint32Array());
    }
  }

  async sync(document) {
    const uri = document.uri.toString();
    const timer = this.timers.get(uri);
    if (timer) {
      clearTimeout(timer);
      this.timers.delete(uri);
    }
    await this.starting;
    if (!this.documents.has(uri)) return;
    if (this.synced.get(uri) === document.version) return;
    this.sendChange(document);
  }

  async format(document, options) {
    const config = vscode.workspace.getConfiguration(languageId);
    const tabSize =
      options && Number.isInteger(options.tabSize) ? options.tabSize : 2;
    const lineWidth = Number(config.get('format.lineWidth'));
    const singleLineIf = config.get('format.singleLineIf') !== false;
    try {
      await this.sync(document);
      const edits = await this.request('textDocument/formatting', {
        textDocument: { uri: document.uri.toString() },
        options: {
          tabSize,
          insertSpaces: true,
          lineWidth: Number.isInteger(lineWidth) ? lineWidth : 80,
          singleLineIf,
        },
      });
      if (!Array.isArray(edits)) return [];
      return edits.map(
        (edit) =>
          new vscode.TextEdit(
            new vscode.Range(
              edit.range.start.line,
              edit.range.start.character,
              edit.range.end.line,
              edit.range.end.character,
            ),
            edit.newText,
          ),
      );
    } catch (error) {
      vscode.window.showErrorMessage(`Quds format failed: ${error.message}`);
      return [];
    }
  }

  sendOpen(document) {
    this.synced.set(document.uri.toString(), document.version);
    this.notify('textDocument/didOpen', {
      textDocument: {
        uri: document.uri.toString(),
        languageId,
        version: document.version,
        text: document.getText(),
      },
    });
  }

  sendChange(document) {
    this.synced.set(document.uri.toString(), document.version);
    this.notify('textDocument/didChange', {
      textDocument: { uri: document.uri.toString(), version: document.version },
      contentChanges: [{ text: document.getText() }],
    });
  }

  request(method, params) {
    const id = this.nextId++;
    const promise = new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
    });
    this.send({ jsonrpc: '2.0', id, method, params });
    return promise;
  }

  notify(method, params) {
    this.send({ jsonrpc: '2.0', method, params });
  }

  send(message) {
    if (!this.child || !this.child.stdin.writable) {
      this.failPending('Language server is not running');
      return;
    }
    const json = JSON.stringify(message);
    this.child.stdin.write(`Content-Length: ${Buffer.byteLength(json)}\r\n\r\n${json}`);
  }

  onData(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (true) {
      const headerEnd = this.buffer.indexOf('\r\n\r\n');
      if (headerEnd < 0) return;
      const header = this.buffer.slice(0, headerEnd).toString('utf8');
      const match = /Content-Length: (\d+)/i.exec(header);
      if (!match) {
        this.output.appendLine('Expected a Content-Length header');
        return;
      }
      const length = Number(match[1]);
      const start = headerEnd + 4;
      if (this.buffer.length < start + length) return;
      const body = this.buffer.slice(start, start + length).toString('utf8');
      this.buffer = this.buffer.slice(start + length);
      let message;
      try {
        message = JSON.parse(body);
      } catch (error) {
        this.output.appendLine(error.message);
        continue;
      }
      this.onMessage(message);
    }
  }

  onMessage(message) {
    if (message.method === 'textDocument/publishDiagnostics') {
      this.showDiagnostics(message.params || {});
      return;
    }
    if (message.id == null || !this.pending.has(message.id)) return;
    const pending = this.pending.get(message.id);
    this.pending.delete(message.id);
    if (message.error) pending.reject(new Error(message.error.message || 'Language server error'));
    else pending.resolve(message.result);
  }

  showDiagnostics(params) {
    let uri;
    try {
      uri = vscode.Uri.parse(params.uri);
    } catch (error) {
      this.output.appendLine(error.message);
      return;
    }
    const items = (params.diagnostics || []).map((item) => {
      const diagnostic = new vscode.Diagnostic(
        new vscode.Range(
          item.range.start.line,
          item.range.start.character,
          item.range.end.line,
          item.range.end.character,
        ),
        item.message,
        item.severity === 2
          ? vscode.DiagnosticSeverity.Warning
          : vscode.DiagnosticSeverity.Error,
      );
      diagnostic.code = item.code;
      diagnostic.source = item.source || languageId;
      return diagnostic;
    });
    this.diagnostics.set(uri, items);
  }

  failPending(message) {
    for (const pending of this.pending.values()) pending.reject(new Error(message));
    this.pending.clear();
  }
}

module.exports = { activate, deactivate };
