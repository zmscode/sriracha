c:
	@clear
	@rm -rf zig-out

b:
	@clear
	@zig build

r:
	@clear
	@zig build run

rc:
	@make c
	@make r

crc:
	@make c
	@make r
	@make c

t:
	@clear
	@zig build test
