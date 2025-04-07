const std = @import("std");
const spacetime = @import("spacetime.zig");
const utils = @import("spacetime/utils.zig");
comptime { _ = spacetime; }

pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = spacetime.logFn,
};

const TableAttribs = struct {
    scheduled: ?[]const u8,
    autoinc: ?[]const []const u8,
    primary_key: ?[]const u8,
    unique: ?[]const []const u8,
};

const TableAttribsPair = struct {
    schema: type,
    attribs: TableAttribs,
};

comptime {
    var attributeList: []const TableAttribsPair = &.{};
}

fn removeComptimeFields(data: type) type {
    const typeInfo = @typeInfo(data).@"struct";
    var newFields: []const std.builtin.Type.StructField = &.{};

    inline for(std.meta.fields(data)) |field| {
        if(!field.is_comptime) {
            newFields = newFields ++ &[_]std.builtin.Type.StructField{ field };
        }
    }

    return @Type(.{
        .@"struct" = std.builtin.Type.Struct{
            .backing_integer = typeInfo.backing_integer,
            .decls = typeInfo.decls,
            .fields = newFields,
            .is_tuple = typeInfo.is_tuple,
            .layout = typeInfo.layout,
        }
    });
}

fn Table(data: type) spacetime.Table {
    const fieldIdx = std.meta.fieldIndex(data, "__spacetime_10.0__attribs__");
    if(fieldIdx == null) return .{ .schema = data, .schema_name = @typeName(data), };

    const attribs: TableAttribs = utils.getMemberDefaultValue(data, "__spacetime_10.0__attribs__");
    return .{
        .schema = removeComptimeFields(data),
        .schema_name = @typeName(data),
        .primary_key = attribs.primary_key,
        //.schedule_reducer = attribs.scheduled,
        .unique = attribs.unique,
        .autoinc = attribs.autoinc,
    };
}

fn TableSchema(data: TableAttribsPair) type {
    const attribs: TableAttribs = data.attribs;

    attributeList = attributeList ++ &[1]TableAttribsPair{ data };

    var newFields: []const std.builtin.Type.StructField = &.{};

    newFields = newFields ++ &[_]std.builtin.Type.StructField{
       std.builtin.Type.StructField{
           .alignment = @alignOf(TableAttribs),
           .default_value = @ptrCast(&attribs),
           .is_comptime = false,
           .name = "__spacetime_10.0__attribs__",
           .type = TableAttribs,
       }
    };

    newFields = newFields ++ std.meta.fields(data.schema);
    const newStruct: std.builtin.Type.Struct = .{
        .backing_integer = null,
        .decls = &[_]std.builtin.Type.Declaration{},
        .fields = newFields,
        .is_tuple = false,
        .layout = .auto
    };
    return @Type(.{
        .@"struct" = newStruct,
    });
}

//#[spacetimedb::table(name = move_all_players_timer, scheduled(move_all_players))]
pub const move_all_players_timer = Table(MoveAllPlayersTimer);
pub const MoveAllPlayersTimer = TableSchema(.{
    .schema = struct {
        scheduled_id: u64,
        scheduled_at: spacetime.ScheduleAt,
    },
    .attribs = TableAttribs{
        .scheduled = "move_all_players_reducer",
        .autoinc = &.{"scheduled_id"},
        .primary_key = "scheduled_id",
        .unique = &.{},
    }
});

pub const Init: spacetime.Reducer = .{ .func_type = @TypeOf(InitReducer), .func = @ptrCast(&InitReducer), .lifecycle = .Init, };
pub fn InitReducer(ctx: *spacetime.ReducerContext) !void {
    std.log.info("Initializing...", .{});
    try ctx.db.get("move_all_players_timer").insert(MoveAllPlayersTimer{
        .scheduled_id = 0,
        .scheduled_at = .{ .Interval = .{ .__time_duration_micros__ = 50 * std.time.us_per_ms }}
    });
}

pub const move_all_players = spacetime.Reducer{
    .func_type = @TypeOf(move_all_players_reducer),
    .func = @ptrCast(&move_all_players_reducer),
    .params = &.{ "timer" }
};
pub fn move_all_players_reducer(ctx: *spacetime.ReducerContext, timer: MoveAllPlayersTimer) !void {
    _ = ctx;
    std.log.info("(id: {}) Move Players!", .{timer.scheduled_id});
    return;
}

// pub const say_hello = spacetime.Reducer{ .func_type = @TypeOf(say_hello_reducer), .func = @ptrCast(&say_hello_reducer)};

// pub fn say_hello_reducer(ctx: *spacetime.ReducerContext) !void {
//     _ = ctx;
//     std.log.info("Hello!", .{});
//     return;
// }

