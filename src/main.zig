const std = @import("std");
const alloc = @import("root.zig").alloc;
const zeys = @import("zeys");

const Intel4001 = @import("4001.zig").Intel4001;
const Intel4004 = @import("4004.zig").Intel4004;
const Intel4002 = @import("4002.zig").Intel4002;
const TIMING = @import("enum.zig").TIMING;
const Clock = @import("clock.zig");

const Computer = struct {
    enable_state: u8,
    cpu: *Intel4004,
    roms: [16]*Intel4001,
    rams: [4]*Intel4002,

    fn sync(self: *Computer, t: u2, num: u4) void {
        var bus: u4 = 0;
        const cmrom: u1 = self.cpu.cm;
        const cmram: u1 = @truncate(self.cpu.cmram & 1);
        
        if (t == 0) { // cpu
            bus = self.cpu.buffer;
        } else if (t == 1) { // roms
            bus = self.roms[num].buffer;
        } else { // rams
            bus = self.rams[num].buffer;
        }

        self.cpu.buffer = bus;
        for (&self.roms) |*rom| {
            rom.*.buffer = bus;
            rom.*.cm = cmrom;
        }
        for (&self.rams) |*ram| {
            ram.*.buffer = bus;
            ram.*.cm = cmram;
        }

        if (self.cpu.sync == 1 and self.cpu.step == TIMING.A1) {
            for (&self.roms) |*rom| {
                rom.*.step = TIMING.X3;
            }
            for (&self.rams) |*ram| {
                ram.*.step = TIMING.X3;
            }
            self.cpu.sync = 0;
        }
    }

    fn tick(self: *Computer) void {
        self.cpu.tick();
        self.sync(0, 0);
        
        for (&self.roms) |*rom| {
            rom.*.tick();
            self.sync(1, rom.*.chip_num);
        }
        for (&self.rams) |*ram| {
            ram.*.tick();
            self.sync(2, ram.*.chip_num);
        }

        Clock.p1 = false;
        Clock.p2 = false;
    }

    fn splitCopyROM(dest: *[0x200 * 0x10]u4, source: [0x100 * 0x10]u8) void {
        var i: u32 = 0;
        while (i < 0x200) {
            dest[i * 2 + 0] = @intCast(source[i] >> 4);
            dest[i * 2 + 1] = @truncate(source[i]);
            i += 1;
        }
    }

    fn getROM(self: *Computer, filename: []const u8) !*u4 {
        var file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var str: [0x100 * 0x10]u8 = [_]u8{0} ** (0x100 * 0x10);
        var checkStr: [3]u8 = .{0, 0, 0};
        _ = try file.read(&checkStr);
        if (!std.mem.eql(u8, &checkStr, "i44")) { return error.NotI4004File; }

        try file.seekTo(0x10);
        _ = try file.read(&str);

        var rom: [0x200 * 0x10]u4 = [_]u4{0} ** (0x200 * 0x10);

        splitCopyROM(&rom, str);

        _ = self;
        return &rom[0];
    }

    fn copyROM(dest: *[0x200]u4, source: *u4) void {
        var s: *u4 = source;
        var i: u16 = 0;
        while (i < 0x200) {
            dest[i] = s.*;
            s = @ptrFromInt(@intFromPtr(s) + 1);
            i += 1;
        }
    }

    pub fn init() !*Computer {
        const self: *Computer = try alloc.create(Computer);

        self.cpu = try Intel4004.init();
        var fileROM: *u4 = try self.getROM("input.i44");

        var i: u8 = 0;
        while (i < 16) {
            var rom: [0x200]u4 = undefined;
            copyROM(&rom, fileROM);
            self.roms[i] = try Intel4001.init(@intCast(i), &rom);

            i, _ = @addWithOverflow(i, 1);
            fileROM = @ptrFromInt(@intFromPtr(fileROM) + 200);
        }

        i = 0;
        while (i < 4) {
            self.rams[i] = try Intel4002.init(@intCast(i));
            i += 1;
        }

        return self;
    }
};

pub fn main() !void {
    // startup
    var comp: *Computer = try Computer.init();
    Clock.setTime = std.time.nanoTimestamp();

    std.debug.print("\x1B[H\x1B[2J", .{});

    // emulate
    var count: u32 = 0;
    comp.cpu.reset = true;
    for (&comp.roms) |*rom| {
        rom.*.reset = true;
    }
    while (true) {
        Clock.tick();
        if (Clock.p2) {
            count += 1;
        }
        comp.tick();
        if (count == 64) {
            comp.cpu.reset = false;
            for (&comp.roms) |*rom| {
                rom.*.reset = false;
            }
        }
        // if (count == 64 + (4 * 8)) {
        //     break;
        // }
    }
}