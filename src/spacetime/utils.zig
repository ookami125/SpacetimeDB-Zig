// Copyright 2025 Tyler Peterson, Licensed under MPL-2.0

const std = @import("std");

pub fn getMemberDefaultType(t: type, comptime member: []const u8) type {
    const field = std.meta.fields(t)[std.meta.fieldIndex(t, member).?];
    return field.type;
}

pub fn getMemberDefaultValue(t: type, comptime member: []const u8) getMemberDefaultType(t, member) {
    const field = std.meta.fields(t)[std.meta.fieldIndex(t, member).?];
    const value = @as(*const field.type, @alignCast(@ptrCast(field.default_value))).*;
    return value;
}

pub fn itoa(comptime value: anytype) [:0]const u8 {
    comptime var s: []const u8 = &[_]u8{};
    comptime var n = value;
    if (n == 0) {
        s = s ++ .{'0'};
    } else {
        comptime while (n != 0) {
            s = s ++ .{'0' + (n % 10)};
            n = n / 10;
        };
    }
    return @ptrCast(s ++ .{0});
}