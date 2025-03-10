const std = @import("std");
const spacetime = @import("spacetime.zig");

pub fn print(fmt: []const u8) void {
    spacetime.console_log(2, null, 0, null, 0, 0, fmt.ptr, fmt.len);
}

const moduleDef = .{
    .Person = spacetime.Table(Person){ .name = "person" },
    .Init = spacetime.Reducer(Init){ .lifecycle = .Init },
    .OnConnect = spacetime.Reducer(OnConnect){ .lifecycle = .OnConnect },
    .OnDisconnect = spacetime.Reducer(OnDisconnect){ .lifecycle = .OnDisconnect },
    .add = spacetime.Reducer(add){},
    .say_hello = spacetime.Reducer(say_hello){},
};

pub fn callReducer(comptime mdef: anytype, id: usize, args: anytype) void {
    comptime var i = 0;
    inline for(std.meta.fields(@TypeOf(mdef))) |field| {
        if( comptime std.mem.endsWith(u8, @typeName(field.type), "spacetime_10.0__reducer_")) {
            if(id == i) {
                const func = @as(*const field.type, @alignCast(@ptrCast(field.default_value.?))).*.func;
                if(std.meta.fields(@TypeOf(args)).len == @typeInfo(@TypeOf(func)).@"fn".params.len) {
                    return @call(.auto, func, args);
                }
            
                const name: []const u8 = @as(*const field.type, @alignCast(@ptrCast(field.default_value.?))).*.name orelse field.name;
                var buf: [128]u8 = undefined;
                print(std.fmt.bufPrint(&buf, "invalid number of args passed to {s}, expected {} got {}", .{name, @typeInfo(@TypeOf(func)).@"fn".params.len, std.meta.fields(@TypeOf(args)).len}) catch "!!!Error while printing last error!!!");
                @panic("invalid number of args passed to func");
            }
            i += 1;
        }
    }
}

export fn __describe_module__(description: spacetime.BytesSink) void {
    const allocator = std.heap.wasm_allocator;
    print("Hello from Zig!");
    
    var moduleDefBytes = std.ArrayList(u8).init(allocator);
    defer moduleDefBytes.deinit();

    spacetime.serialize_module(&moduleDefBytes, comptime spacetime.compile(moduleDef)) catch {
        print("Allocator Error: Cannot continue!");
        @panic("Allocator Error: Cannot continue!");
    };

    spacetime.write_to_sink(description, moduleDefBytes.items);
}

export fn __call_reducer__(
    id: usize,
    sender_0: u64,
    sender_1: u64,
    sender_2: u64,
    sender_3: u64,
    conn_id_0: u64,
    conn_id_1: u64,
    timestamp: u64,
    args: spacetime.BytesSource,
    err: spacetime.BytesSink,
) i16 {
    //const allocator = std.heap.wasm_allocator;
    _ = args;
    _ = err;

    var ctx: spacetime.ReducerContext = .{
        .indentity = std.mem.bytesAsValue(u256, std.mem.sliceAsBytes(&[_]u64{ sender_0, sender_1, sender_2, sender_3})).*,
        .timestamp = timestamp,
        .connection_id  = std.mem.bytesAsValue(u128, std.mem.sliceAsBytes(&[_]u64{ conn_id_0, conn_id_1})).*,
    };

    switch(id) {
        0...2, 4 => {
            callReducer(moduleDef, id, .{ &ctx });
        },
        3 => {
            callReducer(moduleDef, id, .{ &ctx, "blah" });
        },
        else => unreachable,
    } 


    return 0;
}

pub const Person = struct{
    name: []u8,
};

pub fn Init(_ctx: *spacetime.ReducerContext) void {
    // Called when the module is initially published
    _ = _ctx;
    print("Hello, Init!");
}

pub fn OnConnect(_ctx: *spacetime.ReducerContext) void {
    // Called everytime a new client connects
    _ = _ctx;
    print("Hello, OnConnect!");
}

pub fn OnDisconnect(_ctx: *spacetime.ReducerContext) void {
    // Called everytime a client disconnects
    _ = _ctx;
    print("Hello, OnDisconnect!");
}

pub fn add(_ctx: *spacetime.ReducerContext, name: []const u8) void {
    _ = _ctx;
    //ctx.db.person().insert(Person { name });
    var buf: [128]u8 = undefined;
    print(std.fmt.bufPrint(&buf, "Hello, add({s})!", .{ name }) catch "[add] Error: name to long");
}

//#[spacetimedb::reducer]
pub fn say_hello(_ctx: *spacetime.ReducerContext) void {
    //for person in ctx.db.person().iter() {
    //    log::info!("Hello, {}!", person.name);
    //}
    //log::info!("Hello, World!");
    _ = _ctx;
    print("Hello, World!");
}