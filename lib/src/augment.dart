import 'dart:convert';
import 'dart:io';
import 'ast.dart';
import 'hash.dart';
import 'source.dart';
import 'type_syntax.dart';

/// Normalize augment ASTs before symbols and constructors are registered.
/// No imported class is mutated: storage merges only within a declared library.
Map<String, Program> normalizeAugments(Map<String, Program> programs) {
  if (!programs.values.any((p) => p.statements
      .whereType<ClassDeclaration>()
      .any((c) => c.kind == 'augment'))) return programs;
  Never fail(String code, String message, Node node) =>
      throw CompilerException(code, message, node.span);
  String canonical(String path) => path.startsWith('quds:') || path == '<input>'
      ? path
      : File(path).absolute.uri.normalizePath().toFilePath();
  String resolve(String path, String uri) =>
      canonical(Uri.file(path).resolve(uri).toFilePath());
  final groups = <String, List<String>>{};
  for (final e in programs.entries) {
    final ofs = e.value.statements
        .whereType<PartDirective>()
        .where((p) => p.of)
        .toList();
    final home =
        ofs.length == 1 ? resolve(e.key, ofs.single.uri) : canonical(e.key);
    if (ofs.length == 1) {
      final parent = programs[home];
      if (parent == null ||
          !parent.statements
              .whereType<PartDirective>()
              .any((p) => !p.of && resolve(home, p.uri) == canonical(e.key)))
        fail('E903', 'part of does not match the owning library', ofs.single);
    }
    groups.putIfAbsent(home, () => []).add(e.key);
  }
  final replacements = <ClassDeclaration, ClassDeclaration>{};
  final extensions = <ClassDeclaration, ExtensionDeclaration>{};
  final removed = <ClassDeclaration>{};
  for (final group in groups.values) {
    final classes = <String, ClassDeclaration>{};
    for (final path in group)
      for (final c in programs[path]!.statements.whereType<ClassDeclaration>())
        if (c.kind != 'augment') classes.putIfAbsent(c.name, () => c);
    final additions = <ClassDeclaration, List<ClassDeclaration>>{};
    for (final path in group)
      for (final aug in programs[path]!
          .statements
          .whereType<ClassDeclaration>()
          .where((c) => c.kind == 'augment')) {
        if (aug.superclass != null ||
            aug.mixins.isNotEmpty ||
            aug.interfaces.isNotEmpty ||
            aug.modifiers.isNotEmpty ||
            aug.annotations.isNotEmpty)
          fail(
              'E720',
              'augment does not change inheritance, modifiers or annotations',
              aug);
        final head = aug.name.split('<').first;
        final owner = classes[head];
        if (owner != null) {
          if (aug.name.contains('<') &&
              splitTypeList(aug.name.substring(
                          aug.name.indexOf('<') + 1, aug.name.length - 1))
                      .join(',') !=
                  owner.typeParameters.map((p) => p.name).join(','))
            fail('E300', 'augment must use the original formal type parameters',
                aug);
          additions.putIfAbsent(owner, () => []).add(aug);
          removed.add(aug);
        } else {
          if (aug.fields.isNotEmpty ||
              aug.constructors.isNotEmpty ||
              aug.cases.isNotEmpty)
            fail(
                'E910',
                'External augment cannot add storage, constructors or cases',
                aug);
          if (aug.methods.any((m) => m.isStatic))
            fail(
                'E910',
                'External static augment members need further conformance',
                aug);
          if (aug.methods.any((m) => m.visibility.isNotEmpty) ||
              aug.properties.any((p) => p.visibility.isNotEmpty))
            fail(
                'E910',
                'External augment members cannot grant private or protected access',
                aug);
          final id =
              sha256Hex(utf8.encode('${aug.span.file}:${aug.span.offset}'))
                  .substring(0, 12);
          extensions[aug] = ExtensionDeclaration(
              '\$QudsAugment$id', aug.name, aug.methods, aug.span,
              typeParameters: aug.typeParameters, properties: aug.properties);
        }
      }
    for (final e in additions.entries) {
      final c = e.key;
      final fields = [...c.fields, for (final a in e.value) ...a.fields];
      final methods = [...c.methods, for (final a in e.value) ...a.methods];
      final properties = [
        ...c.properties,
        for (final a in e.value) ...a.properties
      ];
      final constructors = [
        ...c.constructors,
        for (final a in e.value) ...a.constructors
      ];
      final names = <String>{};
      for (final field in fields)
        if (!names.add(field.name))
          fail('E201', 'Duplicate augmented member: ${field.name}', field);
      for (final property in properties)
        if (!names.add(property.name))
          fail(
              'E201', 'Duplicate augmented member: ${property.name}', property);
      for (final method in methods)
        if (!names.add(method.isOperator
            ? 'operator ${method.name}/${method.parameters.length}'
            : method.name))
          fail('E201', 'Duplicate augmented member: ${method.name}', method);
      final ctors = <String>{};
      for (final ctor in constructors)
        if (!ctors.add(ctor.name ?? ''))
          fail('E201', 'Duplicate augmented constructor', ctor);
      if (const {'enum', 'sealedType', 'extensionType'}.contains(c.kind))
        fail(
            'E910',
            'This declaration cannot merge augment storage or bodies yet',
            e.value.first);
      replacements[c] = ClassDeclaration(
          c.name, c.kind, fields, methods, c.cases, c.annotations, c.span,
          superclass: c.superclass,
          mixins: c.mixins,
          interfaces: c.interfaces,
          onType: c.onType,
          modifiers: c.modifiers,
          requirements: c.requirements,
          constructors: constructors,
          properties: properties,
          typeParameters: c.typeParameters,
          documentation: c.documentation);
    }
  }
  return {
    for (final e in programs.entries)
      e.key: Program([
        for (final node in e.value.statements)
          if (node is! ClassDeclaration)
            node
          else if (!removed.contains(node))
            extensions[node] ?? replacements[node] ?? node
      ], e.value.span)
  };
}
