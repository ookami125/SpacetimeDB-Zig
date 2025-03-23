const std = @import("std");
const spacetime = @import("spacetime.zig");

pub export fn spacetime_includes() void {
    _ = &spacetime.__describe_module__;
    _ = &spacetime.__call_reducer__;
}

pub const moduleTablesDef = .{
    .person = spacetime.Table(.{.name = "person", .layout = Person}),
    .person2 = spacetime.Table(.{.name = "person2", .layout = Person}),
};

pub const moduleReducersDef = .{
    .Init = spacetime.Reducer(Init){ .lifecycle = .Init },
    .OnConnect = spacetime.Reducer(OnConnect){ .lifecycle = .OnConnect },
    .OnDisconnect = spacetime.Reducer(OnDisconnect){ .lifecycle = .OnDisconnect },
    .add = spacetime.Reducer(add){ .param_names = &[_][:0]const u8{ "name" }},
    .say_hello = spacetime.Reducer(say_hello){},
};

pub const DbVector2 = spacetime.Struct(.{
    .name = "DbVector2",
    .fields = &[_]spacetime.StructFieldDecl{
        .{ .name = "x", .type = f32, },
        .{ .name = "y", .type = f32 },
    },
});

pub const Person = spacetime.Struct(.{
    .name = "person",
    .fields = &[_]spacetime.StructFieldDecl{
        .{ .name = "name", .type = []const u8, },
        .{ .name = "pos", .type = DbVector2, },
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

pub fn add(ctx: *spacetime.ReducerContext, name: []const u8) void {
   const personTable = ctx.*.db.get(moduleTablesDef.person);
   personTable.insert(Person{ .name = name, .pos = DbVector2{ .x = 10.4, .y = 20.6 } });

   var buf: [128]u8 = undefined;
   spacetime.print(std.fmt.bufPrint(&buf, "[add] {{{s}}}!", .{ name }) catch "[add] Error: name to long");
}

pub fn say_hello(ctx: *spacetime.ReducerContext) void {
   var personIter = ctx.*.db.get(moduleTablesDef.person).iter();
   while(personIter.next() catch {
      @panic("person Iter errored!");
   }) |person| {
      var buffer: [512]u8 = undefined;
      const msg = std.fmt.bufPrint(&buffer, "Hello, {s} (pos: {{{d}, {d}}})!", .{ person.name, person.pos.x, person.pos.y }) catch "<Unknown>";
      spacetime.print(msg);
   }
   spacetime.print("Hello, World!");
}