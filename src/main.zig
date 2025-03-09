const std = @import("std");
const spacetime = @import("spacetime.zig");

const reducers = spacetime.parse_reducers(@This());

pub fn print(fmt: []const u8) void {
    spacetime.console_log(2, null, 0, null, 0, 0, fmt.ptr, fmt.len);
}

const moduleDef: spacetime.RawModuleDefV9 = .{
    .typespace = .{
        .types = &[_]spacetime.AlgebraicType{
            .{
                .Product = .{
                    .elements = &[_]spacetime.ProductTypeElement{
                        .{
                            .name = "name",
                            .algebraic_type = .String,
                        }
                    }
                }
            },
        },
    },
    .tables = &[_]spacetime.RawTableDefV9{
        .{
            .name = "person",
            .product_type_ref = .{ .inner = 0, },
            .primary_key = &[_]u16{},
            .indexes = &[_]spacetime.RawIndexDefV9{},
            .constraints = &[_]spacetime.RawConstraintDefV9{},
            .sequences = &[_]spacetime.RawSequenceDefV9{},
            .schedule = null,
            .table_type = .User,
            .table_access = .Private,
        }
    },
    .reducers = reducers,
        //&[_]spacetime.RawReducerDefV9{
        //.{
        //    .name = "add",
        //    .params = .{
        //        .elements = &[_]spacetime.ProductTypeElement{
        //            .{
        //                .name = "name",
        //                .algebraic_type = .String,
        //            }
        //        }
        //    },
        //    .lifecycle = null,
        //},
        //.{
        //    .name = "identity_connected",
        //    .params = .{ .elements = &[_]spacetime.ProductTypeElement{} },
        //    .lifecycle = .OnConnect,
        //},
        //.{
        //    .name = "identity_disconnected",
        //    .params = .{ .elements = &[_]spacetime.ProductTypeElement{} },
        //    .lifecycle = .OnDisconnect,
        //},
        //.{
        //    .name = "init",
        //    .params = .{ .elements = &[_]spacetime.ProductTypeElement{} },
        //    .lifecycle = .Init,
        //},
        //.{
        //    .name = "say_hello",
        //    .params = .{ .elements = &[_]spacetime.ProductTypeElement{} },
        //    .lifecycle = null,
        //}
    //},
    .types = &[_]spacetime.RawTypeDefV9{
        .{
            .name = .{
                .scope = &[_][]u8{},
                .name = "Person"
            },
            .ty = .{ .inner = 0, },
            .custom_ordering = true,
        }
    },
    .misc_exports = &[_]spacetime.RawMiscModuleExportV9{},
    .row_level_security = &[_]spacetime.RawRowLevelSecurityDefV9{},
};

export fn __describe_module__(description: spacetime.BytesSink) void {
    const allocator = std.heap.wasm_allocator;
    print("Hello from Zig!");
    
    var moduleDefBytes = std.ArrayList(u8).init(allocator);
    defer moduleDefBytes.deinit();

    spacetime.serialize_module(&moduleDefBytes, moduleDef) catch {
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
    const allocator = std.heap.wasm_allocator;

    print(std.fmt.allocPrint(allocator, "id: {}", .{id}) catch "id: err");
    print(std.fmt.allocPrint(allocator, "sender_0: {}", .{sender_0}) catch "sender_0: err");
    print(std.fmt.allocPrint(allocator, "sender_1: {}", .{sender_1}) catch "sender_1: err");
    print(std.fmt.allocPrint(allocator, "sender_2: {}", .{sender_2}) catch "sender_2: err");
    print(std.fmt.allocPrint(allocator, "sender_3: {}", .{sender_3}) catch "sender_3: err");
    print(std.fmt.allocPrint(allocator, "conn_id_0: {}", .{conn_id_0}) catch "conn_id_0: err");
    print(std.fmt.allocPrint(allocator, "conn_id_1: {}", .{conn_id_1}) catch "conn_id_1: err");
    print(std.fmt.allocPrint(allocator, "timestamp: {}", .{timestamp}) catch "timestamp: err");
    print(std.fmt.allocPrint(allocator, "args: {}", .{args}) catch "args: err");
    print(std.fmt.allocPrint(allocator, "err: {}", .{err}) catch "err: err");

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

pub fn add(_ctx: *spacetime.ReducerContext, name: []u8) void {
    _ = _ctx;
    _ = name;
    //ctx.db.person().insert(Person { name });
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