/// A private presentation marker, removed from the wire value by the LSP server.
const nativeDocMarker = '\n<!-- quds-native-doc -->';

String nativeDocumentationHover(String signature, String documentation) =>
    '```quds\n$signature\n```\n\n$documentation$nativeDocMarker';
