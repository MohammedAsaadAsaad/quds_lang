/// English editor documentation for the user-approved loop context receiver.
const loopContextDocs = <String, String>{
  'index':
      'Zero-based index of the nearest enclosing loop body. The first entry is 0. '
          'A nested loop header reads its enclosing loop context.\n\n'
          '```quds\nfor item in [10, 20]:\n  print \$.index\n```',
  'iteration': 'One-based iteration number of the nearest enclosing loop body. '
      'The first entry is 1; entries that continue still count.\n\n'
      '```quds\nrepeat 3:\n  print \$.iteration\n```',
  'item': 'The current for-in binding, with its original static type. '
      'Available in for-in, await-for and collection-for bodies. '
      'It is unavailable in while, C-style for and repeat.\n\n'
      '```quds\nfor item in [10, 20]:\n  print \$.item\n```',
  'isFirst': 'True only on the first entry of the nearest enclosing loop body. '
      'Reading it does not prefetch an item or inspect the collection length.\n\n'
      '```quds\nfor item in [10, 20]:\n  print \$.isFirst\n```',
};
