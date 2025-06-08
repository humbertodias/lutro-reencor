LOVE    := $(shell which love)
UNAME_S := $(shell uname -s)

# macOS overrides
ifeq ($(UNAME_S), Darwin)
    LOVE := /Applications/love.app/Contents/MacOS/love
endif

run/love:
	$(LOVE) .
