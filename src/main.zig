const std = @import("std");
const spacetime = @import("spacetime.zig");
comptime { _ = spacetime; }

pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = spacetime.logFn,
};

pub const DbVector2 = struct {
    x: f32,
    y: f32,
};

pub const config: spacetime.Table = .{ .schema = Config, .primary_key = "id", .access = .Public, };
pub const Config = struct {
    //#[primary_key]
    id: u32,
    world_size: u64,
};

pub const entity: spacetime.Table = .{ .schema = Entity, .primary_key = "entity_id", .access = .Public };
pub const Entity = struct {
    //#[auto_inc]
    //#[primary_key]
    entity_id: u32,
    position: DbVector2,
    mass: u32,
};

pub const circles: spacetime.Table = .{
    .schema = Circle,
    .primary_key = "entity_id",
    .access = .Public,
    .indexes = &.{ .{ .name = "player_id", .layout = .BTree } },
};
pub const Circle = struct {
    //#[auto_inc]
    //#[primary_key]
    entity_id: u32,
    //#[index(btree)]
    player_id: u32,
    direction: DbVector2,
    speed: f32,
    last_split_time: spacetime.Timestamp,
};

pub const players: spacetime.Table = .{
    .schema = Player,
    .primary_key = "identity",
    .access = .Public,
    .unique = &.{ "player_id" },
    .autoinc = &.{ "player_id" },
};
pub const logged_out_players: spacetime.Table = .{
    .schema = Player,
    .primary_key = "identity",
    .unique = &.{ "player_id" }
};
pub const Player = struct {
    //#[primary_key]
    identity: spacetime.Identity,
    //#[unique]
    //#[auto_inc]
    player_id: u32,
    name: []const u8,

    pub fn destroy(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.destroy(self);
    }
};

pub const food: spacetime.Table = .{ .schema = Food, .primary_key = "entity_id", .access = .Public };
pub const Food = struct {
    //#[primary_key]
    entity_id: u32,
};

//#[spacetimedb::table(name = spawn_food_timer, scheduled(spawn_food))]
pub const spawn_food_timer: spacetime.Table = .{ .schema = SpawnFoodTimer, .primary_key = "scheduled_id" };
pub const SpawnFoodTimer = struct {
    //#[primary_key]
    //#[auto_inc]
    scheduled_id: u64,
    scheduled_at: spacetime.ScheduleAt,
};

//#[spacetimedb::table(name = circle_decay_timer, scheduled(circle_decay))]
pub const circle_decay_timer: spacetime.Table = .{ .schema = CircleDecayTimer, .primary_key = "scheduled_id" };
pub const CircleDecayTimer = struct {
    //#[primary_key]
    //#[auto_inc]
    scheduled_id: u64,
    scheduled_at: spacetime.ScheduleAt,
};

//#[spacetimedb::table(name = circle_recombine_timer, scheduled(circle_recombine))]
pub const circle_recombine_timer: spacetime.Table = .{ .schema = CircleRecombineTimer, .primary_key = "scheduled_id" };
pub const CircleRecombineTimer = struct {
    //#[primary_key]
    //#[auto_inc]
    scheduled_id: u64,
    scheduled_at: spacetime.ScheduleAt,
    player_id: u32,
};

pub const consume_entity_timer: spacetime.Table = .{ .schema = ConsumeEntityTimer, .primary_key = "scheduled_id" };
pub const ConsumeEntityTimer = struct {
    //#[primary_key]
    //#[auto_inc]
    scheduled_id: u64,
    scheduled_at: spacetime.ScheduleAt,
    consumed_entity_id: u32,
    consumer_entity_id: u32,
};

pub const Init: spacetime.Reducer = .{ .func_type = @TypeOf(InitReducer), .func = @ptrCast(&InitReducer), .lifecycle = .Init, };
pub fn InitReducer(ctx: *spacetime.ReducerContext) !void {
    std.log.info("Initializing...", .{});
    try ctx.db.get("config").insert(Config {
        .id = 0,
        .world_size = 1000,
    });
    try ctx.db.get("circle_decay_timer").insert(CircleDecayTimer {
        .scheduled_id = 0,
        .scheduled_at = .{ .Interval = .{ .__time_duration_micros__ = 5 * std.time.us_per_s }},
    });
    try ctx.db.get("spawn_food_timer").insert(SpawnFoodTimer {
        .scheduled_id = 0,
        .scheduled_at = .{ .Interval = .{ .__time_duration_micros__ = 500 * std.time.us_per_ms }}
    });
    try ctx.db.get("move_all_players_timer").insert(MoveAllPlayersTimer {
        .scheduled_id = 0,
        .scheduled_at = .{ .Interval = .{ .__time_duration_micros__ = 50 * std.time.us_per_ms }}
    });
}

pub const OnConnect = spacetime.Reducer{ .func_type = @TypeOf(OnConnectReducer), .func = @ptrCast(&OnConnectReducer), .lifecycle = .OnConnect, };
pub fn OnConnectReducer(ctx: *spacetime.ReducerContext) !void {
    // Called everytime a new client connects
    std.log.info("[OnConnect]", .{});
    const nPlayer = try ctx.db.get("logged_out_players").col("identity").find(.{ .identity = ctx.sender });
    if (nPlayer) |player| {
       try ctx.db.get("players").insert(player.*);
       try ctx.db.get("logged_out_players").col("identity").delete(.{ .identity = player.identity });
    } else {
       try ctx.db.get("players").insert(Player {
           .identity = ctx.sender,
           .player_id = 0,
           .name = "",
       });
    }
}

pub const OnDisconnect = spacetime.Reducer{ .func_type = @TypeOf(OnDisconnectReducer), .func = @ptrCast(&OnDisconnectReducer), .lifecycle = .OnDisconnect, };
pub fn OnDisconnectReducer(ctx: *spacetime.ReducerContext) !void {
    // Called everytime a client disconnects
    std.log.info("[OnDisconnect]", .{});
    const nPlayer = try ctx.db.get("players").col("identity").find(.{ .identity = ctx.sender});
    if(nPlayer == null) {
        std.log.err("Disconnecting player doesn't have a valid players row!",.{});
        return;
    }
    const player = nPlayer.?;
    //std.log.info("{?}", .{player});
    const player_id = player.player_id;
    try ctx.db.get("logged_out_players").insert(player.*);
    try ctx.db.get("players").col("identity").delete(.{ .identity = ctx.sender});

    // Remove any circles from the arena
    var iter = ctx.db.get("circles").col("player_id").filter(.{ .player_id = player_id });
    //_ = player_id;
    _ = &iter;
    // std.log.info("blag", .{});
    // while (try iter.next()) |circle_val| {
    //     try ctx.db.get("entity").col("entity_id").delete(.{ .entity_id = circle_val.entity_id, });
    //     try ctx.db.get("circle").col("entity_id").delete(.{ .entity_id = circle_val.entity_id, });
    // }
}

//#[spacetimedb::table(name = move_all_players_timer, scheduled(move_all_players))]
pub const move_all_players_timer: spacetime.Table = .{
    .schema = MoveAllPlayersTimer,
    .primary_key = "scheduled_id",
    .schedule_reducer = &move_all_players
};
pub const MoveAllPlayersTimer = struct {
    //#[primary_key]
    //#[auto_inc]
    scheduled_id: u64,
    scheduled_at: spacetime.ScheduleAt,
};

pub const move_all_players = spacetime.Reducer{
    .func_type = @TypeOf(move_all_players_reducer),
    .func = @ptrCast(&move_all_players_reducer),
    .params = &.{ "_timer" }
};
pub fn move_all_players_reducer(ctx: *spacetime.ReducerContext, _timer: MoveAllPlayersTimer) !void {
    _ = ctx;
    _ = _timer;
    //std.log.info("Move Players!", .{});
    return;
}

pub const say_hello = spacetime.Reducer{ .func_type = @TypeOf(say_hello_reducer), .func = @ptrCast(&say_hello_reducer)};

pub fn say_hello_reducer(ctx: *spacetime.ReducerContext) !void {
    _ = ctx;
    std.log.info("Hello!", .{});
    return;
}

