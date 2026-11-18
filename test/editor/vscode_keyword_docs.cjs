const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const fake = {
  EventEmitter: class {},
  CompletionItem: class { constructor(label, kind) { this.label = label; this.kind = kind; } },
  MarkdownString: class { constructor(value) { this.value = value; this.isTrusted = false; } },
};
const filename = 'editors/vscode/extension.js';
const box = {module: {exports: {}}, require(name) { return name === 'vscode' ? fake : require(name); },
  console, process, Buffer, setTimeout, clearTimeout, __dirname: path.resolve('editors/vscode')};
vm.runInNewContext(fs.readFileSync(filename, 'utf8') + '\nmodule.exports.item = completionItem;', box, {filename});
const item = box.module.exports.item;
const markdown = '### var\n\nMutable binding.\n\n```quds\nvar count = 0\n```';
const result = item({label: 'var', kind: 14, documentation: {kind: 'markdown', value: markdown}});
assert(result.documentation instanceof fake.MarkdownString);
assert.equal(result.documentation.value, markdown);
assert.equal(result.documentation.isTrusted, false);
assert.equal(item({label: 'x', documentation: 'Plain text'}).documentation, 'Plain text');
assert.equal(item({label: 'x', documentation: {kind: 'plaintext', value: '*plain*'}}).documentation, '*plain*');
assert.equal(item({label: 'x'}).documentation, undefined);
console.log('VSCODE KEYWORD DOCS OK');
