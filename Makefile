build:
	zig build --summary all

run:
	zig build run

clean:
	rm -rf .zig-cache zig-out

frontend:
	$(MAKE) -C frontend install

.PHONY: build run clean frontend
