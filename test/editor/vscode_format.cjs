const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const settings = {
  quds: { 'format.onSave': true, 'format.lineWidth': 80, 'format.singleLineIf': true },
  editor: { formatOnSave: false, tabSize: 2 },
};

const fake = {
  TextDocumentSaveReason: { Manual: 1, AfterDelay: 2, FocusOut: 3 },
  EventEmitter: class { fire() {} dispose() {} },
  workspace: {
    getConfiguration(section) {
      const bucket = settings[section] || {};
      return { get(key) { return bucket[key]; } };
    },
  },
};

const filename = 'editors/vscode/extension.js';
const box = {
  module: { exports: {} },
  require(name) { return name === 'vscode' ? fake : require(name); },
  console,
  process,
  Buffer,
  setTimeout,
  clearTimeout,
  __dirname: path.resolve('editors/vscode'),
};
vm.runInNewContext(
  fs.readFileSync(filename, 'utf8') + '\nmodule.exports.shouldAutoFormatOnSave = shouldAutoFormatOnSave;',
  box,
  { filename },
);

const { shouldAutoFormatOnSave } = box.module.exports;
const qudsDoc = { languageId: 'quds', uri: 'file:///demo.quds' };
const dartDoc = { languageId: 'dart', uri: 'file:///demo.dart' };

// Manual save on .quds when global editor.formatOnSave is false -> autoformats.
assert.equal(shouldAutoFormatOnSave({ document: qudsDoc, reason: 1 }), true);
// Non-Quds files -> skipped.
assert.equal(shouldAutoFormatOnSave({ document: dartDoc, reason: 1 }), false);
// Auto-save after delay -> skipped so cursor does not jump mid-typing.
assert.equal(shouldAutoFormatOnSave({ document: qudsDoc, reason: 2 }), false);
// If VS Code built-in editor.formatOnSave is already true -> skip fallback to avoid double formatting.
settings.editor.formatOnSave = true;
assert.equal(shouldAutoFormatOnSave({ document: qudsDoc, reason: 1 }), false);
// If user disables quds.format.onSave -> skipped even when editor.formatOnSave is false.
settings.editor.formatOnSave = false;
settings.quds['format.onSave'] = false;
assert.equal(shouldAutoFormatOnSave({ document: qudsDoc, reason: 1 }), false);

// package.json declares default autoformat on save.
const pkg = JSON.parse(fs.readFileSync('editors/vscode/package.json', 'utf8'));
assert.equal(pkg.contributes.configurationDefaults['[quds]']['editor.formatOnSave'], true);
assert.equal(pkg.contributes.configurationDefaults['[quds]']['editor.defaultFormatter'], 'quds-lang.quds');
assert.equal(pkg.contributes.configuration.properties['quds.format.onSave'].default, true);

console.log('VSCODE FORMAT OK');
