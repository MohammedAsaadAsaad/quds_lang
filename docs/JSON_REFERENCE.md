# `quds:json` Reference

Type-safe JSON parsing, encoding, typed field/path decoding, deep merging, and structural equality without `dynamic`.

```quds
use quds:json
```

## Parsing & Encoding

| Function | Signature | Notes |
| --- | --- | --- |
| `parseJson` | `(source: String) -> Result<Object?, JsonError>` | Parses any JSON value |
| `parseJsonObject` | `(source: String) -> Result<Map<String, Object?>, JsonError>` | Parses and verifies root object |
| `parseJsonList` | `(source: String) -> Result<List<Object?>, JsonError>` | Parses and verifies root array |
| `jsonAsObject` | `(value: Object?, [path: String = ""]) -> Result<Map<String, Object?>, JsonError>` | Validates map with string keys |
| `jsonAsList` | `(value: Object?, [path: String = ""]) -> Result<List<Object?>, JsonError>` | Validates JSON list |
| `encodeJson` | `(value: Object?, pretty: bool = false, indent: String = "  ") -> String` | Compact or pretty JSON string |
| `jsonPretty` | `(value: Object?, indent: String = "  ") -> String` | Indented multi-line JSON |
| `tryEncodeJson` | `(value: Object?, pretty: bool = false, indent: String = "  ") -> Result<String, JsonError>` | Non-throwing encoder |

## Typed Field Readers (Required & Optional)

- Primitives: `jsonRequireString`, `jsonOptionalString`, `jsonRequireInt`, `jsonOptionalInt`, `jsonRequireDouble`, `jsonOptionalDouble`, `jsonRequireBool`, `jsonOptionalBool`
- Nested containers: `jsonRequireObject`, `jsonOptionalObject`, `jsonRequireList`, `jsonOptionalList`
- Typed primitive arrays (with indexed error paths like `"tags[2]"`): `jsonRequireStringList`, `jsonRequireIntList`, `jsonRequireDoubleList`, `jsonRequireBoolList`
- Structured decoders with path propagation (`"profile.zip"`, `"items[1].id"`):
  - `jsonRequireObjectAs<T>(data, key, decoder)` / `jsonOptionalObjectAs<T>(data, key, decoder)`
  - `jsonRequireListOf<T>(data, key, decoder)` / `jsonOptionalListOf<T>(data, key, decoder)`
- ISO-8601 `DateTime`: `jsonRequireDateTime`, `jsonOptionalDateTime`
- String-mapped enums: `jsonRequireEnum<T>(data, key, allowed)` / `jsonOptionalEnum<T>(data, key, allowed)`

## Dot-Path Queries, Deep Merge & Equality

- `jsonPath(root, path)` — walks `"user.roles.1"` returning `Object?` (`null` if missing)
- Typed path queries returning `Result<T, JsonError>`: `jsonPathString`, `jsonPathInt`, `jsonPathDouble`, `jsonPathBool`
- `jsonMerge(base, overlay, deep: bool = true)` — returns a new merged object without mutating inputs
- `jsonEquals(a, b)` — deep structural JSON equality (key-order independent for objects; numeric `1 == 1.0`)

## Tests

- Primary Quds suite: `test/json_sdk.quds` (`quds test test/json_sdk.quds`)
- VM + JS parity & embedded sync: `test/json_sdk_test.dart`
