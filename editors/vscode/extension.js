const vscode = require('vscode');
const { spawn, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { URL, fileURLToPath, pathToFileURL } = require('url');

const languageId = 'quds';

const sectionPattern =
  /^[A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)*$/;

// Keep these folds in step with foldingRanges in lib/src/libraries.dart.
function foldingRangesFor(lines) {
  return [
    ...sectionFolds(lines),
    ...markerFolds(lines),
    ...indentFolds(lines),
  ];
}

function sectionFolds(lines) {
  const headers = [];
  for (let i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith('::')) continue;
    let path = lines[i].slice(2).trim();
    const comment = path.indexOf('#');
    if (comment >= 0) path = path.slice(0, comment).trimEnd();
    headers.push({ line: i, path, fold: sectionPattern.test(path) });
  }
  const ranges = [];
  for (let i = 0; i < headers.length; i++) {
    const header = headers[i];
    if (!header.fold) continue;
    let end = lines.length - 1;
    for (let j = i + 1; j < headers.length; j++) {
      if (headers[j].path.startsWith(`${header.path}::`)) continue;
      end = headers[j].line - 1;
      break;
    }
    while (end > header.line && lines[end].trim() === '') end--;
    if (end <= header.line) continue;
    ranges.push({
      startLine: header.line,
      endLine: end,
      kind: 'region',
      collapsedText: header.path,
    });
  }
  return ranges;
}

function markerFolds(lines) {
  const open = /^\s*#\s*region\b\s*(.*)$/;
  const close = /^\s*#\s*end\s+region\b/;
  const stack = [];
  const ranges = [];
  for (let i = 0; i < lines.length; i++) {
    const start = open.exec(lines[i]);
    if (start) {
      stack.push({ line: i, label: start[1].trim() });
      continue;
    }
    if (close.test(lines[i]) && stack.length) {
      const region = stack.pop();
      if (i <= region.line) continue;
      const range = {
        startLine: region.line,
        endLine: i,
        kind: 'region',
      };
      if (region.label) range.collapsedText = region.label;
      ranges.push(range);
    }
  }
  return ranges;
}

function indentFolds(lines) {
  const stack = [];
  const ranges = [];
  let last = lines.length - 1;
  while (last > 0 && lines[last].trim() === '') last--;
  function close(indent, end) {
    while (stack.length && indent <= stack[stack.length - 1].indent) {
      const start = stack.pop();
      let line = end;
      while (line > start.line && lines[line].trim() === '') line--;
      if (line > start.line) {
        ranges.push({ startLine: start.line, endLine: line });
      }
    }
  }
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() === '') continue;
    const indent = indentWidth(lines[i]);
    close(indent, i - 1);
    stack.push({ line: i, indent });
  }
  close(-1, last);
  return ranges;
}

function indentWidth(line) {
  let indent = 0;
  for (let i = 0; i < line.length; i++) {
    const unit = line.charCodeAt(i);
    if (unit === 32) indent++;
    else if (unit === 9) indent += 2;
    else break;
  }
  return indent;
}

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
    vscode.languages.registerSignatureHelpProvider(languageId, {
      provideSignatureHelp(document, position, token) {
        return client.signatureHelp(document, position, token);
      },
    }, '(', ','),
    vscode.languages.registerCodeLensProvider(languageId, {
      onDidChangeCodeLenses: client.semanticRefresh.event,
      provideCodeLenses(document) {
        return client.codeLenses(document);
      },
    }),
    vscode.languages.registerDocumentSemanticTokensProvider(
      languageId,
      {
        onDidChangeSemanticTokens: client.semanticRefresh.event,
        provideDocumentSemanticTokens(document, _previousResultId, token) {
          return client.semanticTokens(document, token);
        },
      },
      new vscode.SemanticTokensLegend(
        ['function', 'method', 'property', 'variable', 'parameter', 'class'],
        ['declaration', 'readonly'],
      ),
    ),
    vscode.languages.registerFoldingRangeProvider(languageId, {
      provideFoldingRanges(document) {
        const lines = [];
        for (let i = 0; i < document.lineCount; i++) {
          lines.push(document.lineAt(i).text.replace(/\r$/, ''));
        }
        return foldingRangesFor(lines).map((range) => {
          const kind =
            range.kind === 'region' ? vscode.FoldingRangeKind.Region : undefined;
          const folding = new vscode.FoldingRange(
            range.startLine,
            range.endLine,
            kind,
          );
          if (range.collapsedText) folding.collapsedText = range.collapsedText;
          return folding;
        });
      },
    }),
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
  context.subscriptions.push(registerSdkFileSystem());
  context.subscriptions.push(vscode.workspace.onDidOpenTextDocument((document) => {
    if (document.uri.scheme === 'quds-sdk' && document.languageId !== 'quds') {
      vscode.languages.setTextDocumentLanguage(document, 'quds');
    }
  }));
}

const sdkDocuments = new Map();
const sdkFileEvents = new vscode.EventEmitter();

function rememberSdkDocument(uri, text) {
  const parsed = vscode.Uri.parse(uri);
  const value = String(text ?? '');
  sdkDocuments.set(parsed.toString(), value);
  sdkDocuments.set(parsed.path, value);
  const leaf = parsed.path.split('/').pop();
  if (leaf) sdkDocuments.set(leaf, value);
}

function registerSdkFileSystem() {
  return vscode.workspace.registerFileSystemProvider(
    'quds-sdk',
    {
      onDidChangeFile: sdkFileEvents.event,
      watch() {
        return new vscode.Disposable(() => {});
      },
      stat(uri) {
        const text = sdkText(uri);
        if (text == null) throw vscode.FileSystemError.FileNotFound(uri);
        return {
          type: vscode.FileType.File,
          ctime: 0,
          mtime: 0,
          size: Buffer.byteLength(text),
          permissions: vscode.FilePermission.Readonly,
        };
      },
      readFile(uri) {
        const text = sdkText(uri);
        if (text == null) throw vscode.FileSystemError.FileNotFound(uri);
        return Buffer.from(text);
      },
      writeFile() {
        throw vscode.FileSystemError.NoPermissions();
      },
      readDirectory() {
        return [];
      },
      createDirectory() {
        throw vscode.FileSystemError.NoPermissions();
      },
      delete() {
        throw vscode.FileSystemError.NoPermissions();
      },
      rename() {
        throw vscode.FileSystemError.NoPermissions();
      },
    },
    { isReadonly: true },
  );
}

function sdkText(uri) {
  const leaf = uri.path.split('/').pop();
  for (const key of [uri.toString(), uri.path, leaf]) {
    if (key && sdkDocuments.has(key)) return sdkDocuments.get(key);
  }
  if (!leaf || !leaf.endsWith('.quds')) return null;
  const folders = vscode.workspace.workspaceFolders || [];
  for (const folder of folders) {
    const file = vscode.Uri.joinPath(folder.uri, 'lib', 'sdk', leaf);
    try {
      const text = require('fs').readFileSync(file.fsPath, 'utf8');
      sdkDocuments.set(uri.path, text);
      sdkDocuments.set(leaf, text);
      return text;
    } catch (_) {
      // The library may exist only in the compiler's embedded copy.
    }
  }
  return null;
}

function completionItem(entry) {
  const kind = Math.max(0, Number(entry.kind || 1) - 1);
  const item = new vscode.CompletionItem(entry.label, kind);
  if (entry.detail) item.detail = entry.detail;
  if (typeof entry.documentation === 'string') {
    item.documentation = entry.documentation;
  } else if (entry.documentation && typeof entry.documentation.value === 'string') {
    item.documentation = entry.documentation.kind === 'markdown'
      ? new vscode.MarkdownString(entry.documentation.value)
      : entry.documentation.value;
  }
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
  if (documentPath) starts.push(path.dirname(documentPath));
  for (const folder of vscode.workspace.workspaceFolders ?? []) {
    starts.push(folder.uri.fsPath);
  }
  const dart = resolveDart();
  for (const start of starts) {
    const root = packageRoot(start);
    if (!root || !dart) continue;
    const binary = cliBinary(root);
    if (freshCli(root)) {
      return {
        command: [binary, 'lsp'],
        cwd: root,
        env: toolEnv(dart),
        rebuild: freshCli(root) == null,
        root,
        dart,
      };
    }
    return {
      command: [dart, 'run', path.join(root, 'bin', 'quds.dart'), 'lsp'],
      cwd: root,
      env: toolEnv(dart),
      rebuild: true,
      root,
      dart,
    };
  }
  const quds = resolveQuds();
  if (quds && dart) {
    return { command: [quds, 'lsp'], cwd: undefined, env: toolEnv(dart) };
  }
  return { command: [quds || 'quds', 'lsp'], cwd: undefined, env: process.env };
}

function scheduleRebuild(client, root, dart) {
  if (!root || !dart || client.rebuilding) return;
  client.rebuilding = true;
  const binary = cliBinary(root);
  fs.mkdirSync(path.dirname(binary), { recursive: true });
  client.output.appendLine('Rebuilding the Quds language server');
  const child = spawn(
    dart,
    ['compile', 'exe', '-o', binary, path.join(root, 'bin', 'quds.dart')],
    { cwd: root },
  );
  child.stdout.on('data', (chunk) => client.output.append(chunk.toString()));
  child.stderr.on('data', (chunk) => client.output.append(chunk.toString()));
  child.on('error', (error) => {
    client.rebuilding = false;
    client.output.appendLine(error.message);
  });
  child.on('exit', (code) => {
    client.rebuilding = false;
    if (code !== 0 || !fs.existsSync(binary)) {
      client.output.appendLine('Quds language server rebuild failed');
      return;
    }
    client.output.appendLine('Restarting the language server');
    client.restart();
  });
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
  dir = path.resolve(start);
  seen.clear();
  while (dir && !seen.has(dir)) {
    seen.add(dir);
    const config = path.join(dir, '.dart_tool', 'package_config.json');
    if (fs.existsSync(config)) {
      try {
        const entry = JSON.parse(fs.readFileSync(config, 'utf8')).packages
          .find((item) => item.name === 'quds_lang');
        if (entry) {
          const root = fileURLToPath(new URL(entry.rootUri, pathToFileURL(config)));
          const spec = path.join(root, 'pubspec.yaml');
          if (fs.existsSync(path.join(root, 'bin', 'quds.dart')) &&
              fs.existsSync(spec) && /^name:\s*quds_lang\s*$/m.test(fs.readFileSync(spec, 'utf8'))) return root;
        }
      } catch (_) { /* Unresolved pub config falls back to the installed CLI. */ }
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

function cliBinary(root) {
  return path.join(root, '.dart_tool', 'quds', 'quds');
}

function sourcesNewer(root, stamp) {
  const pubspec = path.join(root, 'pubspec.yaml');
  if (fs.existsSync(pubspec) && fs.statSync(pubspec).mtimeMs > stamp) return true;
  const stack = [path.join(root, 'lib'), path.join(root, 'bin')];
  while (stack.length) {
    const dir = stack.pop();
    if (!fs.existsSync(dir)) continue;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        stack.push(full);
        continue;
      }
      if (entry.name.endsWith('.dart') && fs.statSync(full).mtimeMs > stamp) return true;
    }
  }
  return false;
}

function freshCli(root) {
  const binary = cliBinary(root);
  if (!fs.existsSync(binary)) return null;
  if (sourcesNewer(root, fs.statSync(binary).mtimeMs)) return null;
  return binary;
}

function compileCli(root, dart) {
  const binary = cliBinary(root);
  fs.mkdirSync(path.dirname(binary), { recursive: true });
  const built = spawnSync(
    dart,
    ['compile', 'exe', '-o', binary, path.join(root, 'bin', 'quds.dart')],
    { cwd: root, encoding: 'utf8' },
  );
  if (built.status !== 0 || !fs.existsSync(binary)) return null;
  return binary;
}

function launchSpec(file, verb) {
  const dart = resolveDart();
  const root = packageRoot(path.dirname(file));
  if (root && dart) {
    let binary = freshCli(root);
    if (!binary && verb === 'debug') binary = compileCli(root, dart);
    if (binary) {
      return { command: [binary, verb, file], cwd: root, env: toolEnv(dart) };
    }
    if (verb !== 'debug') {
      const target = cliBinary(root);
      const script = [
        quote(dart),
        'compile',
        'exe',
        '-o',
        quote(target),
        quote(path.join(root, 'bin', 'quds.dart')),
        '&&',
        'exec',
        quote(target),
        quote(verb),
        quote(file),
      ].join(' ');
      return { command: ['bash', '-lc', script], cwd: root, env: toolEnv(dart) };
    }
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
    this.semanticRefresh = new vscode.EventEmitter();
    this.nextId = 1;
    this.buffer = Buffer.alloc(0);
    this.documents = new Map();
    this.synced = new Map();
    this.timers = new Map();
    this.maximumTimers = new Map();
    this.child = null;
    this.ready = false;
    this.starting = null;
    this.rebuilding = false;
  }

  start() {
    if (this.starting) return this.starting;
    const sample = [...this.documents.values()][0];
    const spec = serverCommand(sample && sample.uri.fsPath);
    const { command, cwd, env } = spec;
    this.output.appendLine(`Starting ${command.join(' ')}`);
    if (spec.rebuild) scheduleRebuild(this, spec.root, spec.dart);
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
    for (const timer of this.maximumTimers.values()) clearTimeout(timer);
    this.semanticRefresh.dispose();
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
    this.timers.set(uri, setTimeout(() => this.flushChange(uri), 75));
    if (!this.maximumTimers.has(uri)) {
      this.maximumTimers.set(uri, setTimeout(() => this.flushChange(uri), 150));
    }
  }

  flushChange(uri) {
    clearTimeout(this.timers.get(uri));
    clearTimeout(this.maximumTimers.get(uri));
    this.timers.delete(uri);
    this.maximumTimers.delete(uri);
    const document = this.documents.get(uri);
    if (this.ready && document) this.sendChange(document);
  }

  close(document) {
    if (document.languageId !== languageId) return;
    const uri = document.uri.toString();
    this.documents.delete(uri);
    this.synced.delete(uri);
    const timer = this.timers.get(uri);
    if (timer) clearTimeout(timer);
    this.timers.delete(uri);
    clearTimeout(this.maximumTimers.get(uri));
    this.maximumTimers.delete(uri);
    this.diagnostics.delete(document.uri);
    if (this.ready) {
      this.notify('textDocument/didClose', { textDocument: { uri } });
    }
  }

  async complete(document, position, token) {
    const version = document.version;
    try {
      await this.sync(document);
      if (token && token.isCancellationRequested) return undefined;
      const result = await this.request('textDocument/completion', {
        textDocument: { uri: document.uri.toString() },
        position: { line: position.line, character: position.character },
      }, { token, timeoutMs: 5000 });
      if (document.version !== version || (token && token.isCancellationRequested)) return undefined;
      const raw = result && Array.isArray(result.items) ? result.items : [];
      const items = raw.map((entry) => completionItem(entry));
      return new vscode.CompletionList(items, !!(result && result.isIncomplete));
    } catch (error) {
      this.output.appendLine(error.message);
      return undefined;
    }
  }

  async signatureHelp(document, position, token) {
    const version = document.version;
    try {
      await this.sync(document);
      if (token && token.isCancellationRequested) return undefined;
      const result = await this.request('textDocument/signatureHelp', {
        textDocument: { uri: document.uri.toString() },
        position: { line: position.line, character: position.character },
      }, { token });
      if (document.version !== version || !result || (token && token.isCancellationRequested)) return undefined;
      const help = new vscode.SignatureHelp();
      help.signatures = (result.signatures || []).map((entry) => {
        const signature = new vscode.SignatureInformation(entry.label);
        signature.parameters = (entry.parameters || []).map((p) => new vscode.ParameterInformation(p.label));
        return signature;
      });
      help.activeSignature = result.activeSignature || 0;
      help.activeParameter = result.activeParameter || 0;
      return help;
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
      if (typeof result.sdkText === 'string') {
        rememberSdkDocument(result.uri, result.sdkText);
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
      if (contents && contents.kind === 'markdown') {
        const markdown = new vscode.MarkdownString(value);
        return new vscode.Hover(markdown);
      }
      const markdown = new vscode.MarkdownString();
      markdown.appendCodeblock(value, 'quds');
      return new vscode.Hover(markdown);
    } catch (error) {
      this.output.appendLine(error.message);
      return undefined;
    }
  }

  async codeLenses(document) {
    const version = document.version;
    try {
      await this.sync(document);
      const lenses = await this.request('textDocument/codeLens', {
        textDocument: { uri: document.uri.toString() },
      });
      if (document.version !== version || !Array.isArray(lenses)) return [];
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

  async semanticTokens(document, token) {
    const version = document.version;
    try {
      await this.sync(document);
      const result = await this.request('textDocument/semanticTokens/full', {
        textDocument: { uri: document.uri.toString() },
      }, { token });
      if (document.version !== version) return new vscode.SemanticTokens(new Uint32Array());
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
    clearTimeout(this.maximumTimers.get(uri));
    this.maximumTimers.delete(uri);
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

  request(method, params, { token, timeoutMs = 15000 } = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      if (token && token.isCancellationRequested) { resolve(undefined); return; }
      let timer;
      let cancellation;
      const finish = (callback, value) => {
        this.pending.delete(id);
        clearTimeout(timer);
        if (cancellation) cancellation.dispose();
        callback(value);
      };
      const pending = {
        resolve: (value) => finish(resolve, value),
        reject: (error) => finish(reject, error),
      };
      this.pending.set(id, pending);
      timer = setTimeout(() => {
        if (!this.pending.has(id)) return;
        this.notify('$/cancelRequest', { id });
        pending.reject(new Error(`Quds ${method} timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      if (token && typeof token.onCancellationRequested === 'function') {
        cancellation = token.onCancellationRequested(() => {
          if (!this.pending.has(id)) return;
          this.notify('$/cancelRequest', { id });
          pending.resolve(undefined);
        });
        if (!this.pending.has(id)) cancellation.dispose();
      }
      if (this.pending.has(id)) this.send({ jsonrpc: '2.0', id, method, params });
    });
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
    if (message.method === 'quds/semanticTokensReady') {
      const params = message.params || {};
      const document = this.documents.get(params.uri);
      if (document && document.version === params.version) this.semanticRefresh.fire();
      return;
    }
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
    const document = this.documents.get(params.uri);
    if (document && params.version != null && params.version !== document.version) return;
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
    if (params.qudsAnalysisComplete !== false) this.semanticRefresh.fire();
  }

  failPending(message) {
    for (const pending of this.pending.values()) pending.reject(new Error(message));
    this.pending.clear();
  }
}

module.exports = { activate, deactivate };
