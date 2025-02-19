const std = @import("std");
const alloc = @import("root.zig").alloc;

const Clock = @import("clock.zig");
const TIMING = @import("enum.zig").TIMING;
const incStep = @import("enum.zig").incStep;
const op_list = @import("opcodes.zig").op_list;

pub const Intel4004 = struct {
    buffer: u4,
    acc: u4,
    temp: u4,
    instr: u8,
    carry: bool,
    stack: [4]u12,
    reg: [16]u4,

    prev_instr: u8,
    step: TIMING,

    sync: u1,
    cm: u1,
    cmram: u4,
    testP: bool,
    reset: bool,

    pub fn init() !*Intel4004 {
        const i: *Intel4004 = try alloc.create(Intel4004);
        return i;
    }

    fn interpret(self: *Intel4004) void {
        // std.debug.print("INSTRUCTION: 0x{X}\n", .{self.instr});
        if (self.prev_instr != 0) {
            op_list[@divFloor(self.prev_instr, 0x10)](self);
        } else {
            op_list[@divFloor(self.instr, 0x10)](self);
        }
    }

    fn print_state(self: *Intel4004) void {
        // std.debug.print("\x1B[H", .{});
        std.debug.print("|| INSTR: 0x{X:0>2} ||\n> ACC: 0x{X:0>1}  C: {}\n> REGS:\n  > 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}\n  > 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}\n  > 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}\n  > 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}\n\n", .{
            self.instr,
            self.acc, @intFromBool(self.carry),
            self.reg[0], self.reg[1], self.reg[2], self.reg[3],
            self.reg[4], self.reg[5], self.reg[6], self.reg[7],
            self.reg[8], self.reg[9], self.reg[10], self.reg[11],
            self.reg[12], self.reg[13], self.reg[14], self.reg[15],
        });
    }

    pub fn tick(self: *Intel4004) void {
        if (!Clock.p1 and !Clock.p2) return;

        if (self.reset) {
            self.zeroOut();
            return;
        }

        if (Clock.p1) {
            switch (self.step) {
                TIMING.A1 => {
                    self.cm = 1;
                    self.buffer  = @intCast((self.stack[0] >> 8) % 16);
                },
                TIMING.A2 => self.buffer += @intCast((self.stack[0] >> 4) % 16),
                TIMING.A3 => {
                    self.buffer += @intCast((self.stack[0] >> 0) % 16);
                    self.cm = 0;
                    self.stack[0] += 1;
                },
                TIMING.M2 => {
                    if ((self.instr >> 4) == 0xE) self.cmram = 1;
                },
                TIMING.X1 => {
                    self.cmram = 0;
                    self.interpret();
                },
                TIMING.X2 => {
                    self.interpret();
                },
                TIMING.X3 => {
                    self.sync = 1;
                    self.interpret();
                    self.print_state();
                },
                else => {}
            }
        } else if (Clock.p2) {
            switch (self.step) {
                TIMING.M1 => self.instr  = @as(u8, self.buffer) << 4,
                TIMING.M2 => self.instr += @as(u8, self.buffer) << 0,
                else => {}
            }
            // std.debug.print("CPU step: {any}\n", .{self.step});
            incStep(&self.step);
        }

    }

    fn zeroOut(self: *Intel4004) void {
        self.buffer = 0;
        self.acc = 0;
        self.temp = 0;
        self.instr = 0;
        self.carry = false;
        for (&self.stack) |*s| {
            s.* = 0;
        }
        for (&self.reg) |*r| {
            r.* = 0;
        }
        self.prev_instr = 0;
        self.step = TIMING.A1;
        self.sync = 0;
        self.cm = 0;
        self.cmram = 0;
        self.testP = false;
    }
};

