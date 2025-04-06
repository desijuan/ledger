BUILD_MODES := DEFAULT DEBUG OPTIMIZE

MODE ?= DEFAULT
ifeq ($(filter $(MODE),native $(BUILD_MODES)),)
$(error Wrong build mode: '$(MODE)')
endif

APP := app.js

$(APP): $(wildcard src/*.elm)
ifeq ($(MODE),DEFAULT)
	elm make src/Main.elm --output=$@
else ifeq ($(MODE),DEBUG)
	elm make src/Main.elm --output=$@ --debug
else ifeq ($(MODE),OPTIMIZE)
	elm make src/Main.elm --output=$@ --optimize
else
	$(error Wrong build mode: '$(MODE)')
endif

public/$(APP): $(APP)
	cp $(APP) public/

run: public/$(APP)
	http-server-spa public

clean:
	rm -rf elm-stuff $(APP) public/$(APP)

install:
	@$(MAKE) --no-print-directory clean $(APP) MODE=OPTIMIZE
	cp $(APP) public/

PHONY: run clean install
