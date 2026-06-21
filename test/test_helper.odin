package test

import "checksum_helper"

// run with
// odin test test/ -all-packages -collection:project=.
// NOTE: can't use `-vet` since `vendor/glob` doesn't pass it

// mark as "used"
_ :: checksum_helper
