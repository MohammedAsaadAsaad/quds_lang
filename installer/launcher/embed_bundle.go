//go:build bundle

package main

import _ "embed"

//go:embed payload.zip
var embeddedPayload []byte
