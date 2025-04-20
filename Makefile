OPT_ENUM := Debug ReleaseSafe ReleaseFast ReleaseSmall

OPTIMIZE ?= Debug
ifeq ($(filter $(OPTIMIZE),$(OPT_ENUM)),)
$(error Invalid option: '$(OPTIMIZE)')
endif

BIN := ledger
OUT_DIR := zig-out/bin

$(OUT_DIR)/$(BIN):
	zig build -Doptimize=$(OPTIMIZE) --summary all

run: $(OUT_DIR)/$(BIN) frontend
	$<

debug: OPTIMIZE := Debug
debug: $(OUT_DIR)/$(BIN)

release: OPTIMIZE := ReleaseSmall
release: $(OUT_DIR)/$(BIN)

clean:
	rm -rf .zig-cache zig-out

frontend:
	$(MAKE) -C frontend release

httpz-update:
	zig fetch --save git+https://github.com/karlseguin/http.zig#master

.PHONY: $(OUT_DIR)/$(BIN) run debug release clean frontend httpz-update
