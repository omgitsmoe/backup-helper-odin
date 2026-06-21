test *ARGS:
    odin test test/ -all-packages -collection:project=. {{ARGS}}

test-debug *ARGS:
    odin test test/ -all-packages -collection:project=. -define:ODIN_TEST_LOG_LEVEL=debug {{ARGS}}
