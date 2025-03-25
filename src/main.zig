const std = @import("std");
const spacetime = @import("spacetime.zig");

pub export fn spacetime_includes() void {
    _ = &spacetime.__describe_module__;
    _ = &spacetime.__call_reducer__;
}

pub const DbVector2 = struct {
    x: f32,
    y: f32,
};

pub const person: spacetime.Table = .{ .schema = Person, };
pub const Person = struct{
    name: []const u8,
    pos: DbVector2,
    schedule: spacetime.ScheduleAt,
};

pub const Init: spacetime.Reducer = .{
    .func_type = @TypeOf(InitReducer),
    .func = @ptrCast(&InitReducer),
    .lifecycle = .Init,
};

pub fn InitReducer(_: *spacetime.ReducerContext) void {
    // Called when the module is initially published
    spacetime.print("[Init]");
}

pub const OnConnect = spacetime.Reducer{ .func_type = @TypeOf(OnConnectReducer), .func = @ptrCast(&OnConnectReducer), .lifecycle = .OnConnect, };
pub fn OnConnectReducer(_: *spacetime.ReducerContext) void {
    // Called everytime a new client connects
    spacetime.print("[OnConnect]");
}

pub const OnDisconnect = spacetime.Reducer{ .func_type = @TypeOf(OnDisconnectReducer), .func = @ptrCast(&OnDisconnectReducer), .lifecycle = .OnDisconnect, };
pub fn OnDisconnectReducer(_: *spacetime.ReducerContext) void {
    // Called everytime a client disconnects
    spacetime.print("[OnDisconnect]");
}

pub const add = spacetime.Reducer{ .func_type = @TypeOf(addReducer), .func = @ptrCast(&addReducer), .params = &.{ "name", "time" }};
pub fn addReducer(ctx: *spacetime.ReducerContext, name: []const u8, time: i64) void {
    const personTable = ctx.*.db.get("person");
    personTable.insert(Person{
        .name = name,
        .pos = DbVector2{ .x = 10.4, .y = 20.6 },
        .schedule = .{ .Interval = .{ .__time_duration_micros__ = time, }, },
    });

   var buf: [128]u8 = undefined;
   spacetime.print(std.fmt.bufPrint(&buf, "[add] {{{s}}}!", .{ name }) catch "[add] Error: name to long");
}

pub const say_hello = spacetime.Reducer{ .func_type = @TypeOf(say_helloReducer), .func = @ptrCast(&say_helloReducer), };
pub fn say_helloReducer(ctx: *spacetime.ReducerContext) void {
    //_ = ctx;
    var personIter = ctx.*.db.get("person").iter();
    while(personIter.next() catch {
       @panic("person Iter errored!");
    }) |item| {
       var buffer: [512]u8 = undefined;
       const msg = std.fmt.bufPrint(&buffer, "Hello, {s} (pos: {{{d}, {d}}}) (time: {})!", .{ item.name, item.pos.x, item.pos.y, item.schedule.Interval.__time_duration_micros__ }) catch "<Unknown>";
       spacetime.print(msg);
    }
    spacetime.print("Hello, World!");
}