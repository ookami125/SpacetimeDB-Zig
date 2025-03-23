const std = @import("std");
const spacetime = @import("spacetime.zig");

pub export fn spacetime_includes() void {
    _ = &spacetime.__describe_module__;
    _ = &spacetime.__call_reducer__;
}

pub const moduleTablesDef = .{
    .Person = Person,
};

pub const moduleReducersDef = .{
    .Init = spacetime.Reducer(Init){ .lifecycle = .Init },
    .OnConnect = spacetime.Reducer(OnConnect){ .lifecycle = .OnConnect },
    .OnDisconnect = spacetime.Reducer(OnDisconnect){ .lifecycle = .OnDisconnect },
    .add = spacetime.Reducer(add){ .param_names = &[_][:0]const u8{ "name", "age", "blah" }},
    .say_hello = spacetime.Reducer(say_hello){},
};

pub const Person = spacetime.Struct(.{
    .name = "person",
    .fields = &[_]spacetime.StructFieldDecl{
        .{ .name = "name", .type = .String, },
        .{ .name = "age", .type = .U32, },
        .{ .name = "blah", .type = .U64, },
    },
});

pub fn Init(ctx: *spacetime.ReducerContext) void {
    // Called when the module is initially published
    _ = ctx;
    spacetime.print("[Init]");
}

pub fn OnConnect(ctx: *spacetime.ReducerContext) void {
    // Called everytime a new client connects
    _ = ctx;
    spacetime.print("[OnConnect]");
}

pub fn OnDisconnect(ctx: *spacetime.ReducerContext) void {
    // Called everytime a client disconnects
    _ = ctx;
    spacetime.print("[OnDisconnect]");
}

pub fn add(ctx: *spacetime.ReducerContext, name: []const u8, age: u32, blah: u64) void {
    const personTable = ctx.*.db.get(moduleTablesDef.Person);
    personTable.insert(Person{ .name = name, .age = age, .blah = blah });

    var buf: [128]u8 = undefined;
    spacetime.print(std.fmt.bufPrint(&buf, "[add] {{{s}, {}}}!", .{ name, age }) catch "[add] Error: name to long");
}

pub fn say_hello(ctx: *spacetime.ReducerContext) void {
    var personIter = ctx.*.db.get(moduleTablesDef.Person).iter();
    while(personIter.next() catch {
        @panic("person Iter errored!");
    }) |person| {
        var buffer: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "Hello, {s} (age: {})!", .{ person.name, person.age }) catch "<Unknown>";
        spacetime.print(msg);
    }
    spacetime.print("Hello, World!");
}