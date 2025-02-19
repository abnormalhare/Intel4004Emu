const std = @import("std");
const alloc = @import("root.zig").alloc;

const Clock = @import("clock.zig");
const TIMING = @import("enum.zig").TIMING;
const incStep = @import("enum.zig").incStep;

pub const Intel4001 = struct {
    chip_num: u4,
    rom: [0x200]u4,
    is_chip: bool,

    buffer: u4,
    io: u4,
    clear: bool,
    sync: u1,
    cm: u1,
    reset: bool,
    address: u8,
    data: u4,
    step: TIMING,
    instr: u2,

    pub fn init(chip_num: u4, rom: *const [0x200]u4) !*Intel4001 {
        const i = try alloc.create(Intel4001);
        
        i.chip_num = chip_num;
        i.rom = rom.*;
        i.is_chip = false;

        return i;
    }

    pub fn tick(self: *Intel4001) void {
        if (!Clock.p1 and !Clock.p2) return;

        if (self.reset) {
            self.zeroOut();
            return;
        }

        if (Clock.p1) {
            switch (self.step) {
                TIMING.M1 => self.getData(0),
                TIMING.M2 => self.getData(1),
                else => {}
            }
        } else if (Clock.p2) {
            switch (self.step) {
                TIMING.A1 => self.checkROM(self.buffer),
                TIMING.A2 => self.address = @as(u8, self.buffer) << 4,
                TIMING.A3 => self.address = @as(u8, self.buffer) << 0,
                else => {}
            }
            incStep(&self.step);
        }

    }

    fn checkROM(self: *Intel4001, num: u4) void {
        self.is_chip = self.chip_num == num;
    }

    fn getData(self: *Intel4001, offset: u8) void {
        if (!self.is_chip) return;

        self.buffer = self.rom[@as(u32, self.address) * 2 + offset];
    }

    fn zeroOut(self: *Intel4001) void {
        self.buffer = 0;
        self.io = 0;
        self.clear = false;
        self.sync = 0;
        self.cm = 0;
        self.address = 0;
        self.data = 0;
        self.step = TIMING.A1;
        self.instr = 0;
    }
};