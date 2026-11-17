'use strict';
const inspector = require('node:inspector');
const v8 = require('node:v8');
const path = require('node:path');
if (typeof global.gc !== 'function') throw Error('Use node --expose-gc');
const session = new inspector.Session();
session.connect();
const phases = ['baseline', 'retained', 'released', 'copies', 'views', 'weak_cache_after_removal'];
const snapshots = [];
const output = [];
let pending = 0;
let programDone = false;
let finished = false;
let failure;
const originalLog = console.log;
console.log = (...items) => output.push(items.join(' '));
function summarize(profile) {
  let bytes = 0;
  let programBytes = 0;
  function visit(node) {
    bytes += node.selfSize;
    if (node.callFrame.url.endsWith('program.js')) programBytes += node.selfSize;
    for (const child of node.children || []) visit(child);
  }
  visit(profile.head);
  return {sampled_bytes: bytes, program_stack_sampled_bytes: programBytes,
    sample_count: (profile.samples || []).length};
}
function finish() {
  if (!programDone || pending !== 0 || finished) return;
  finished = true;
  try {
    if (failure) throw failure;
    if (snapshots.length !== phases.length || output.join('\n') !== '213097200') throw Error(`Workload phases/checksum disagree: ${snapshots.length}, ${output}`);
    process.stdout.write(JSON.stringify({schema: 1, node: process.version, v8: process.versions.v8,
      mode: 'Dart JavaScript, synchronous phase hooks and GC; inspector allocation sampling includes collected objects',
      sampling_interval_bytes: 128, checksum: 213097200, snapshots}, null, 2) + '\n');
  } catch (error) { console.error(error); process.exitCode = 1; }
  finally { console.log = originalLog; session.disconnect(); }
}
function post(method, params, callback) {
  pending++;
  session.post(method, params, (error, result) => {
    if (error) failure = error;
    else if (callback) callback(result);
    pending--;
    finish();
  });
}
// Dart 3.13.7's developer patch invokes this host function. A synchronous
// hook measures the actual phase, without racing same-thread debugger events.
globalThis.debugger = function qudsProfilePause() {
  const phase = phases[snapshots.length];
  if (!phase) throw Error('Unexpected extra workload pause');
  if (phase === 'baseline') post('HeapProfiler.startSampling', {
    samplingInterval: 128, includeObjectsCollectedByMajorGC: true,
    includeObjectsCollectedByMinorGC: true
  });
  global.gc();
  const snapshot = {phase, heap: v8.getHeapStatistics(), process: process.memoryUsage()};
  snapshots.push(snapshot);
  post('HeapProfiler.getSamplingProfile', {}, result => { snapshot.allocation = summarize(result.profile); });
};
try {
  require(path.resolve(process.argv[2]));
  post('HeapProfiler.stopSampling', {});
} catch (error) { failure = error; }
programDone = true;
finish();
