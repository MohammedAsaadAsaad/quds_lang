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
      provideDocumentFormattingEdits(document) {
        return client.format(document);
      },
    }),
    vscode.workspace.onDidOpenTextDocument((document) => client.open(document)),
    vscode.workspace.onDidChangeTextDocument((event) =>
      client.change(event.document),
    ),
    vscode.workspace.onDidCloseTextDocument((document) =>
      client.close(document),
    ),
    vscode.commands.registerCommand('quds.restartServer', () => client.restart()),
  );
  for (const document of vscode.workspace.textDocuments) {
    client.open(document);
  }
  client.start();
}

function deactivate() {}

function serverCommand() {
  const configured = vscode.workspace.getConfiguration(languageId).get('serverCommand');
  if (Array.isArray(configured) && configured.length > 0) {
    return { command: configured.map(String), cwd: undefined };
  }
  for (const folder of vscode.workspace.workspaceFolders ?? []) {
    const root = folder.uri.fsPath;
    const bin = path.join(root, 'bin', 'quds.dart');
    const pubspec = path.join(root, 'pubspec.yaml');
    if (!fs.existsSync(bin) || !fs.existsSync(pubspec)) continue;
    const text = fs.readFileSync(pubspec, 'utf8');
    if (/^name:\s*quds_lang\s*$/m.test(text)) {
      return { command: ['dart', 'run', bin, 'lsp'], cwd: root };
    }
  }
  return { command: ['quds', 'lsp'], cwd: undefined };
}

class QudsClient {
  constructor(diagnostics, output) {
    this.diagnostics = diagnostics;
    this.output = output;
    this.pending = new Map();
    this.nextId = 1;
    this.buffer = Buffer.alloc(0);
    this.documents = new Map();
    this.timers = new Map();
    this.child = null;
    this.ready = false;
    this.starting = null;
  }

  start() {
    if (this.starting) return this.starting;
    const { command, cwd } = serverCommand();
    this.output.appendLine(`Starting ${command.join(' ')}`);
    this.child = spawn(command[0], command.slice(1), { cwd, stdio: ['pipe', 'pipe', 'pipe'] });
    this.child.stdout.on('data', (chunk) => this.onData(chunk));
    this.child.stderr.on('data', (chunk) => this.output.append(chunk.toString()));
    this.child.on('error', (error) => {
      this.output.appendLine(error.message);
      vscode.window.showErrorMessage(`Quds language server failed to start: ${error.message}`);
    });
    this.child.on('exit', (code) => {
      this.output.appendLine(`Language server exited (${code})`);
      this.failPending(`Language server exited (${code})`);
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
    if (child) child.kill();
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
    const timer = this.timers.get(uri);
    if (timer) clearTimeout(timer);
    this.timers.delete(uri);
    this.diagnostics.delete(document.uri);
    if (this.ready) {
      this.notify('textDocument/didClose', { textDocument: { uri } });
    }
  }

  async format(document) {
    const uri = document.uri.toString();
    const timer = this.timers.get(uri);
    if (timer) {
      clearTimeout(timer);
      this.timers.delete(uri);
    }
    try {
      await this.starting;
      this.sendChange(document);
      const edits = await this.request('textDocument/formatting', {
        textDocument: { uri },
        options: { tabSize: 2, insertSpaces: true },
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
