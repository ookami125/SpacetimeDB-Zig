// Copyright 2025 Clockwork Labs, Licensed under Apache-2.0
// Copyright 2025 Tyler Peterson, Licensed under Apache-2.0

const std = @import("std");
const spacetime = @import("spacetime.zig");
comptime { _ = spacetime; }

const START_PLAYER_MASS: u32 = 15;
const START_PLAYER_SPEED: u32 = 10;
const FOOD_MASS_MIN: u32 = 2;
const FOOD_MASS_MAX: u32 = 4;
const TARGET_FOOD_COUNT: usize = 600;
const MINIMUM_SAFE_MASS_RATIO: f32 = 0.85;

const MIN_MASS_TO_SPLIT: u32 = START_PLAYER_MASS * 2;
const MAX_CIRCLES_PER_PLAYER: u32 = 16;
const SPLIT_RECOMBINE_DELAY_SEC: f32 = 5.0;
const SPLIT_GRAV_PULL_BEFORE_RECOMBINE_SEC: f32 = 2.0;
const ALLOWED_SPLIT_CIRCLE_OVERLAP_PCT: f32 = 0.9;
 //1 == instantly separate circles. less means separation takes time
const SELF_COLLISION_SPEED: f32 = 0.05;

pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = spacetime.logFn,
};

pub const spacespec = spacetime.Spec{
    .tables = &.{
        spacetime.Table{
            .name = "config",
            .schema = Config,
            .attribs = .{
                .access = .Public,
                .primary_key = "id",
            }
        },
        spacetime.Table{
            .name = "entity",
            .schema = Entity,
            .attribs = .{
                .access = .Public,
                .primary_key = "entity_id",
                .autoinc = &.{ "entity_id", },
            }
        },
        spacetime.Table{
            .name = "circle",
            .schema = Circle,
            .attribs = .{
                .access = .Public,
                .primary_key = "entity_id",
                .autoinc = &.{ "entity_id", },
                .indexes = &.{ .{ .name = "player_id", .layout = .BTree }, },
            }
        },
        spacetime.Table{
            .name = "player",
            .schema = Player,
            .attribs = .{
                .access = .Public,
                .primary_key = "identity",
                .autoinc = &.{ "player_id", },
                .unique = &.{ "player_id", },
            }
        },
        spacetime.Table{
            .name = "logged_out_player",
            .schema = Player,
            .attribs = .{
                .access = .Public,
                .primary_key = "identity",
                .unique = &.{ "player_id", },
            }
        },
        spacetime.Table{
            .name = "food",
            .schema = Food,
            .attribs = .{
                .access = .Public,
                .primary_key = "entity_id",
            }
        },
        spacetime.Table{
            .name = "move_all_players_timer",
            .schema = MoveAllPlayersTimer,
            .attribs = .{
                .primary_key = "scheduled_id",
                .autoinc = &.{ "scheduled_id", },
                .schedule = "move_all_players",
            }
        },
        spacetime.Table{
            .name = "spawn_food_timer",
            .schema = SpawnFoodTimer,
            .attribs = .{
                .primary_key = "scheduled_id",
                .autoinc = &.{ "scheduled_id" },
                .schedule = "spawn_food",
            }
        },
        spacetime.Table{
            .name = "circle_decay_timer",
            .schema = CircleDecayTimer,
            .attribs = .{
                .primary_key = "scheduled_id",
                .autoinc = &.{ "scheduled_id" },
                .schedule = "circle_decay",
            }
        },
        spacetime.Table{
            .name = "circle_recombine_timer",
            .schema = CircleRecombineTimer,
            .attribs = .{
                .primary_key = "scheduled_id",
                .autoinc = &.{ "scheduled_id" },
                .schedule = "circle_recombine",
            }
        },
        spacetime.Table{
            .name = "consume_entity_timer",
            .schema = ConsumeEntityTimer,
            .attribs = .{
                .primary_key = "scheduled_id",
                .autoinc = &.{ "scheduled_id" },
                .schedule = "consume_entity",
            }
        }
    },
    .reducers = &.{
        spacetime.Reducer(.{
            .name = "init",
            .lifecycle = .Init,
            .func = &init,
        }),
        spacetime.Reducer(.{
            .name = "client_connected",
            .lifecycle = .OnConnect,
            .func = &connect,
        }),
        spacetime.Reducer(.{
            .name = "client_disconnected",
            .lifecycle = .OnDisconnect,
            .func = &disconnect,
        }),
        spacetime.Reducer(.{
            .name = "enter_game",
            .params = &.{ "name" },
            .func = &enter_game,
        }),
        spacetime.Reducer(.{
            .name = "respawn",
            .func = &respawn,
        }),
        spacetime.Reducer(.{
            .name = "suicide",
            .func = &suicide,
        }),
        spacetime.Reducer(.{
            .name = "update_player_input",
            .func = &update_player_input,
            .params = &.{ "direction", },
        }),
        spacetime.Reducer(.{
            .name = "move_all_players",
            .func = &move_all_players,
            .params = &.{ "_timer", },
        }),
        spacetime.Reducer(.{
            .name = "consume_entity",
            .func = &consume_entity,
            .params = &.{ "request", },
        }),
        spacetime.Reducer(.{
            .name = "player_split",
            .func = &player_split,
        }),
        spacetime.Reducer(.{
            .name = "spawn_food",
            .func = &spawn_food,
            .params = &.{ "_timer", },
        }),
        spacetime.Reducer(.{
            .name = "circle_decay",
            .func = &circle_decay,
            .params = &.{ "_timer", },
        }),
        spacetime.Reducer(.{
            .name = "circle_recombine",
            .func = &circle_recombine,
            .params = &.{ "_timer", },
        })
    },
    .row_level_security = &.{
        "SELECT * FROM logged_out_player WHERE identity = :sender"
    }
};

pub const DbVector2 = struct {
    x: f32,
    y: f32,

    pub fn sqr_magnitude(self: @This()) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub fn magnitude(self: @This()) f32 {
        return @sqrt(self.sqr_magnitude());
    }

    pub fn normalized(self: @This()) DbVector2 {
        const length = self.magnitude();
        return .{
            .x = self.x / length,
            .y = self.y / length,
        };
    }

    pub fn scale(self: @This(), val: f32) DbVector2 {
        return .{
            .x = self.x * val,
            .y = self.y * val,
        };
    }

    pub fn add(self: @This(), other: DbVector2) DbVector2 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn add_to(self: *@This(), other: DbVector2) void {
        self.x += other.x;
        self.y += other.y;
    }

    pub fn sub(self: @This(), other: DbVector2) DbVector2 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
        };
    }

    pub fn sub_from(self: *@This(), other: DbVector2) void {
        self.x -= other.x;
        self.y -= other.y;
    }

};

pub const Config = struct {
    id: u32,
    world_size: u64,
};

pub const Entity = struct {
    entity_id: u32,
    position: DbVector2,
    mass: u32,
};

pub const Circle = struct {
    entity_id: u32,
    player_id: u32,
    direction: DbVector2,
    speed: f32,
    last_split_time: spacetime.Timestamp,
};

pub const Player = struct {
    identity: spacetime.Identity,
    player_id: u32,
    name: []const u8,

    pub fn destroy(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.destroy(self);
    }
};

pub const Food = struct {
    entity_id: u32,
};

pub const SpawnFoodTimer = struct {
    scheduled_id: u64,
    scheduled_at: spacetime.ScheduleAt,
};

pub const CircleDecayTimer = struct {
    scheduled_id: u64,
    scheduled_at: spacetime.ScheduleAt,
};

pub const CircleRecombineTimer = struct {
    scheduled_id: u64,
    scheduled_at: spacetime.ScheduleAt,
    player_id: u32,
};

pub const ConsumeEntityTimer = struct {
    scheduled_id: u64,
    scheduled_at: spacetime.ScheduleAt,
    consumed_entity_id: u32,
    consumer_entity_id: u32,
};

pub const MoveAllPlayersTimer = struct {
    scheduled_id: u64,
    scheduled_at: spacetime.ScheduleAt,
};

pub fn init(ctx: *spacetime.ReducerContext) !void {
    std.log.info("Initializing...", .{});
    _ = try ctx.db.get("config").insert(Config {
        .id = 0,
        .world_size = 1000,
    });
    _ = try ctx.db.get("circle_decay_timer").insert(CircleDecayTimer {
        .scheduled_id = 0,
        .scheduled_at = .{ .Interval = .{ .__time_duration_micros__ = 5 * std.time.us_per_s }},
    });
    _ = try ctx.db.get("spawn_food_timer").insert(SpawnFoodTimer {
        .scheduled_id = 0,
        .scheduled_at = .{ .Interval = .{ .__time_duration_micros__ = 500 * std.time.us_per_ms }}
    });
    _ = try ctx.db.get("move_all_players_timer").insert(MoveAllPlayersTimer {
       .scheduled_id = 0,
       .scheduled_at = .{ .Interval = .{ .__time_duration_micros__ = 50 * std.time.us_per_ms }}
    });
}

pub fn connect(ctx: *spacetime.ReducerContext) !void {
    // Called everytime a new client connects
    std.log.info("[OnConnect]", .{});
    const nPlayer = try ctx.db.get("logged_out_player").col("identity").find(.{ .identity = ctx.sender });
    if (nPlayer) |player| {
       _ = try ctx.db.get("player").insert(player);
       try ctx.db.get("logged_out_player").col("identity").delete(.{ .identity = player.identity });
    } else {
       _ = try ctx.db.get("player").insert(Player {
           .identity = ctx.sender,
           .player_id = 0,
           .name = "",
       });
    }
}

pub fn disconnect(ctx: *spacetime.ReducerContext) !void {
    // Called everytime a client disconnects
    std.log.info("[OnDisconnect]", .{});
    const nPlayer = try ctx.db.get("player").col("identity").find(.{ .identity = ctx.sender});
    if(nPlayer == null) {
        std.log.err("Disconnecting player doesn't have a valid players row!",.{});
        return;
    }

    const player = nPlayer.?;
    _ = try ctx.db.get("logged_out_player").insert(player);
    try ctx.db.get("player").col("identity").delete(.{ .identity = ctx.sender});

    // Remove any circles from the arena
    var iter = try ctx.db.get("circle").col("player_id").filter(.{ .player_id = player.player_id });
    defer iter.close();
    while (try iter.next()) |circle_val| {
        try ctx.db.get("entity").col("entity_id").delete(.{ .entity_id = circle_val.entity_id, });
        try ctx.db.get("circle").col("entity_id").delete(.{ .entity_id = circle_val.entity_id, });
    }
}

pub fn enter_game(ctx: *spacetime.ReducerContext, name: []const u8) !void {
    std.log.info("Creating player with name {s}", .{name});
    var player: ?Player = try ctx.db.get("player").col("identity").find(.{ .identity = ctx.sender });
    const player_id = player.?.player_id;
    player.?.name = name;
    try ctx.db.get("player").col("identity").update(player.?);
    _ = try spawn_player_initial_circle(ctx, player_id);
}

fn gen_range(rng: *std.Random.DefaultPrng, min: f32, max: f32) f32 {
    return @floatCast(std.Random.float(rng.random(), f64) * (@as(f64, @floatCast(max)) - @as(f64, @floatCast(min))) + @as(f64, @floatCast(min)));
}

fn spawn_player_initial_circle(ctx: *spacetime.ReducerContext, player_id: u32) !Entity {
    var rng = ctx.rng;
    const world_size = (try ctx
       .db.get("config").col("id")
       .find(.{ .id = 0, })).?.world_size;
    const player_start_radius = mass_to_radius(START_PLAYER_MASS);
    const x = gen_range(&rng, player_start_radius, (@as(f32, @floatFromInt(world_size)) - player_start_radius));
    const y = gen_range(&rng, player_start_radius, (@as(f32, @floatFromInt(world_size)) - player_start_radius));
    return spawn_circle_at(
        ctx,
        player_id,
        START_PLAYER_MASS,
        DbVector2 { .x = x, .y = y },
        ctx.timestamp,
    );
}

fn spawn_circle_at(
    ctx: *spacetime.ReducerContext,
    player_id: u32,
    mass: u32,
    position: DbVector2,
    timestamp: spacetime.Timestamp,
) !Entity {
    const entity = try ctx.db.get("entity").insert(.{
        .entity_id = 0,
        .position = position,
        .mass = mass,
    });

    _ = try ctx.db.get("circle").insert(.{
        .entity_id = entity.entity_id,
        .player_id = player_id,
        .direction = DbVector2 { .x = 0.0, .y = 1.0 },
        .speed = 0.0,
        .last_split_time = timestamp,
    });

    return entity;
}

//#[spacetimedb::reducer]
pub fn respawn(ctx: *spacetime.ReducerContext) !void {
    const player = (try ctx
        .db.get("player")
        .col("identity")
        .find(.{ .identity = ctx.sender})).?;

    _ = try spawn_player_initial_circle(ctx, player.player_id);
}

//#[spacetimedb::reducer]
pub fn suicide(ctx: *spacetime.ReducerContext) !void {
    const player = (try ctx
        .db
        .get("player")
        .col("identity")
        .find(.{ .identity = ctx.sender})).?;

    var circles = try ctx.db.get("circle").col("player_id").filter(.{ .player_id = player.player_id});
    defer circles.close();

    while(try circles.next()) |circle|  {
        try destroy_entity(ctx, circle.entity_id);
    }
}

//#[spacetimedb::reducer]
pub fn update_player_input(ctx: *spacetime.ReducerContext, direction: DbVector2) !void {
    std.log.info("player input updated!", .{});
    const player = (try ctx
        .db
        .get("player")
        .col("identity")
        .find(.{ .identity = ctx.sender})).?;
    var circles = try ctx.db.get("circle").col("player_id").filter(.{ .player_id = player.player_id});
    defer circles.close();
    while(try circles.next()) |circle| {
        var copy_circle = circle;
        copy_circle.direction = direction.normalized();
        copy_circle.speed = std.math.clamp(direction.magnitude(), 0.0, 1.0);
        try ctx.db.get("circle").col("entity_id").update(copy_circle);
    }
}

fn is_overlapping(a: *Entity, b: *Entity) bool {
    const dx = a.position.x - b.position.x;
    const dy = a.position.y - b.position.y;
    const distance_sq = dx * dx + dy * dy;

    const radius_a = mass_to_radius(a.mass);
    const radius_b = mass_to_radius(b.mass);

    // If the distance between the two circle centers is less than the
    // maximum radius, then the center of the smaller circle is inside
    // the larger circle. This gives some leeway for the circles to overlap
    // before being eaten.
    const max_radius = @max(radius_a, radius_b);
    return distance_sq <= max_radius * max_radius;
}

fn mass_to_radius(mass: u32) f32 {
    return @sqrt(@as(f32, @floatFromInt(mass)));
}

fn mass_to_max_move_speed(mass: u32) f32 {
    return 2.0 * @as(f32, @floatFromInt(START_PLAYER_SPEED)) / (1.0 + @sqrt(@as(f32, @floatFromInt(mass)) / @as(f32, @floatFromInt(START_PLAYER_MASS))));
}

pub fn move_all_players(ctx: *spacetime.ReducerContext, _timer: MoveAllPlayersTimer) !void {
    // TODO identity check
    // let span = spacetimedb::log_stopwatch::LogStopwatch::new("tick");
    //std.log.info("_timer: {}", .{ _timer.scheduled_id });
    _ = _timer;
    const world_size = (try ctx
        .db.get("config").col("id")
        .find(.{ .id = 0 })).?.world_size;
    
    var circle_directions = std.AutoHashMap(u32, DbVector2).init(ctx.allocator);
    var circleIter = try ctx.db.get("circle").iter();
    defer circleIter.close();
    while(try circleIter.next()) |circle| {
        try circle_directions.put(circle.entity_id, circle.direction.scale(circle.speed));
    }

    var playerIter = try ctx.db.get("player").iter();
    defer playerIter.close();

    while(try playerIter.next()) |player|  {
        var circles = std.ArrayList(Circle).init(ctx.allocator);
        var circlesIter1 = try ctx.db.get("circle").col("player_id")
            .filter(.{ .player_id = player.player_id});
        defer circlesIter1.close();
        while(try circlesIter1.next()) |circle| {
            try circles.append(circle);
        }

        var player_entities = std.ArrayList(Entity).init(ctx.allocator);
        for(circles.items) |c| {
            try player_entities.append((try ctx.db.get("entity").col("entity_id").find(.{ .entity_id = c.entity_id})).?);
        }
        if(player_entities.items.len <= 1) {
            continue;
        }
        const count = player_entities.items.len;

        // Gravitate circles towards other circles before they recombine
        for(0..count) |i| {
            const circle_i = circles.items[i];
            const time_since_split = ctx.timestamp
                .DurationSince(circle_i.last_split_time)
                .as_f32(.Seconds);
            const time_before_recombining = @max(SPLIT_RECOMBINE_DELAY_SEC - time_since_split, 0.0);
            if(time_before_recombining > SPLIT_GRAV_PULL_BEFORE_RECOMBINE_SEC) {
                continue;
            }

            const entity_i = player_entities.items[i];
            for (player_entities.items) |entity_j| {
                if(entity_i.entity_id == entity_j.entity_id) continue;
                var diff = entity_i.position.sub(entity_j.position);
                var distance_sqr = diff.sqr_magnitude();
                if(distance_sqr <= 0.0001) {
                    diff = DbVector2{ .x = 1.0, .y = 0.0 };
                    distance_sqr = 1.0;
                }
                const radius_sum = mass_to_radius(entity_i.mass) + mass_to_radius(entity_j.mass);
                if(distance_sqr > radius_sum * radius_sum) {
                    const gravity_multiplier =
                        1.0 - time_before_recombining / SPLIT_GRAV_PULL_BEFORE_RECOMBINE_SEC;
                    const vec = diff.normalized()
                        .scale(radius_sum - @sqrt(distance_sqr))
                        .scale(gravity_multiplier)
                        .scale(0.05)
                        .scale( 1.0 / @as(f32, @floatFromInt(count)));
                    circle_directions.getPtr(entity_i.entity_id).?.add_to(vec.scale( 1.0 / 2.0));
                    circle_directions.getPtr(entity_j.entity_id).?.sub_from(vec.scale( 1.0 / 2.0));
                }
            }
        }

        // Force circles apart
        for(0..count) |i| {
            const slice2 = player_entities.items[i+1..];
            const entity_i = player_entities.items[i];
            for (0..slice2.len) |j| {
                const entity_j = slice2[j];
                var diff = entity_i.position.sub(entity_j.position);
                var distance_sqr = diff.sqr_magnitude();
                if(distance_sqr <= 0.0001) {
                    diff = DbVector2{.x = 1.0, .y = 0.0};
                    distance_sqr = 1.0;
                }
                const radius_sum = mass_to_radius(entity_i.mass) + mass_to_radius(entity_j.mass);
                const radius_sum_multiplied = radius_sum * ALLOWED_SPLIT_CIRCLE_OVERLAP_PCT;
                if(distance_sqr < radius_sum_multiplied * radius_sum_multiplied) {
                    const vec = diff.normalized()
                        .scale(radius_sum - @sqrt(distance_sqr))
                        .scale(SELF_COLLISION_SPEED);
                    circle_directions.getPtr(entity_i.entity_id).?.add_to(vec.scale( 1.0 / 2.0));
                    circle_directions.getPtr(entity_j.entity_id).?.sub_from(vec.scale( 1.0 / 2.0));
                }
            }
        }
    }

    var circleIter2 = try ctx.db.get("circle").iter();
    defer circleIter2.close();
    while(try circleIter2.next()) |circle| {
        const circle_entity_n = (ctx.db.get("entity").col("entity_id").find(.{ .entity_id = circle.entity_id }) catch {
            continue;
        });
        var circle_entity = circle_entity_n.?;
        const circle_radius = mass_to_radius(circle_entity.mass);
        const direction = circle_directions.get(circle.entity_id).?;
        const new_pos = circle_entity.position.add(direction.scale(mass_to_max_move_speed(circle_entity.mass)));
        const min = circle_radius;
        const max = @as(f32, @floatFromInt(world_size)) - circle_radius;
        if(max < min) continue;
        circle_entity.position.x = std.math.clamp(new_pos.x, min, max);
        circle_entity.position.y = std.math.clamp(new_pos.y, min, max);
        try ctx.db.get("entity").col("entity_id").update(circle_entity);
    }

    // Check collisions
    var entities = std.AutoHashMap(u32, Entity).init(ctx.allocator);
    var entitiesIter = try ctx.db.get("entity").iter();
    defer entitiesIter.close();
    while(try entitiesIter.next()) |e| {
        try entities.put(e.entity_id, e);
    }
    var circleIter3 = try ctx.db.get("circle").iter();
    defer circleIter3.close();
    while(try circleIter3.next()) |circle| {
        // let span = spacetimedb::time_span::Span::start("collisions");
        var circle_entity = entities.get(circle.entity_id).?;
        var entityIter = entities.iterator();
        while (entityIter.next()) |other_entity| {
            if(other_entity.value_ptr.entity_id == circle_entity.entity_id) {
                continue;
            }

            if(is_overlapping(&circle_entity, other_entity.value_ptr)) {
                const other_circle_n = try ctx.db.get("circle").col("entity_id").find(.{ .entity_id = other_entity.value_ptr.entity_id });
                if (other_circle_n) |other_circle| {
                    if(other_circle.player_id != circle.player_id) {
                        const mass_ratio = @as(f32, @floatFromInt(other_entity.value_ptr.mass)) / @as(f32, @floatFromInt(circle_entity.mass));
                        if(mass_ratio < MINIMUM_SAFE_MASS_RATIO) {
                            try schedule_consume_entity(
                                ctx,
                                circle_entity.entity_id,
                                other_entity.value_ptr.entity_id,
                            );
                        }
                    }
                } else {
                    try schedule_consume_entity(ctx, circle_entity.entity_id, other_entity.value_ptr.entity_id);
                }
            }
        }
        // span.end();
    }
}

fn schedule_consume_entity(ctx: *spacetime.ReducerContext, consumer_id: u32, consumed_id: u32) !void {
    _ = try ctx.db.get("consume_entity_timer").insert(ConsumeEntityTimer{
        .scheduled_id = 0,
        .scheduled_at = .{ .Time = ctx.timestamp },
        .consumer_entity_id = consumer_id,
        .consumed_entity_id = consumed_id,
    });
}

pub fn consume_entity(ctx: *spacetime.ReducerContext, request: ConsumeEntityTimer) !void {
    const consumed_entity_n = try ctx
        .db.get("entity").col("entity_id")
        .find(.{ .entity_id = request.consumed_entity_id});
    const consumer_entity_n = try ctx
        .db.get("entity").col("entity_id")
        .find(.{ .entity_id = request.consumer_entity_id});
    if(consumed_entity_n == null) {
        return;
    }
    if(consumer_entity_n == null) {
        return;
    }
    const consumed_entity = consumed_entity_n.?;
    var consumer_entity = consumer_entity_n.?;

    consumer_entity.mass += consumed_entity.mass;
    try destroy_entity(ctx, consumed_entity.entity_id);
    try ctx.db.get("entity").col("entity_id").update(consumer_entity);
}

pub fn destroy_entity(ctx: *spacetime.ReducerContext, entity_id: u32) !void {
    try ctx.db.get("food").col("entity_id").delete(.{ .entity_id = entity_id});
    try ctx.db.get("circle").col("entity_id").delete(.{ .entity_id = entity_id});
    try ctx.db.get("entity").col("entity_id").delete(.{ .entity_id = entity_id});
}

pub fn player_split(ctx: *spacetime.ReducerContext) !void {
    const player = (try ctx
        .db.get("player").col("identity")
        .find(.{ .identity = ctx.sender})).?;
    var circles = std.ArrayList(Circle).init(ctx.allocator);
    var circlesIter = try ctx
        .db
        .get("circle")
        .col("player_id")
        .filter(.{ .player_id = player.player_id});
    defer circlesIter.close();
    while(try circlesIter.next()) |circle| {
        try circles.append(circle);
    }
    var circle_count = circles.items.len;
    if(circle_count >= MAX_CIRCLES_PER_PLAYER) {
        return;
    }

    for(circles.items) |c| {
        var circle = c;
        var circle_entity = (try ctx
            .db
            .get("entity")
            .col("entity_id")
            .find(.{ .entity_id = circle.entity_id})).?;
        if(circle_entity.mass >= MIN_MASS_TO_SPLIT * 2) {
            const half_mass = @divTrunc(circle_entity.mass, 2);
            _ = try spawn_circle_at(
                ctx,
                circle.player_id,
                half_mass,
                circle_entity.position.add(circle.direction),
                ctx.timestamp,
            );
            circle_entity.mass -= half_mass;
            circle.last_split_time = ctx.timestamp;
            try ctx.db.get("circle").col("entity_id").update(circle);
            try ctx.db.get("entity").col("entity_id").update(circle_entity);
            circle_count += 1;
            if (circle_count >= MAX_CIRCLES_PER_PLAYER) {
                break;
            }
        }
    }

    _ = try ctx.db
        .get("circle_recombine_timer")
        .insert(CircleRecombineTimer {
            .scheduled_id = 0,
            .scheduled_at = spacetime.ScheduleAt.durationSecs(ctx, SPLIT_RECOMBINE_DELAY_SEC),
            .player_id = player.player_id,
        });

    std.log.warn("Player split!", .{});
}

pub fn spawn_food(ctx: *spacetime.ReducerContext, _: SpawnFoodTimer) !void {
    if(try ctx.db.get("player").count() == 0) {
        //Are there no players yet?
        return;
    }

    const world_size = (try ctx
        .db
        .get("config")
        .col("id")
        .find(.{ .id = 0})).?
        .world_size;

    var rng = ctx.rng;
    var food_count = try ctx.db.get("food").count();
    while (food_count < TARGET_FOOD_COUNT) {
        const food_mass = gen_range(&rng, FOOD_MASS_MIN, FOOD_MASS_MAX);
        const food_radius = mass_to_radius(@intFromFloat(food_mass));
        const x = gen_range(&rng, food_radius, @as(f32, @floatFromInt(world_size)) - food_radius);
        const y = gen_range(&rng, food_radius, @as(f32, @floatFromInt(world_size)) - food_radius);
        const entity = try ctx.db.get("entity").insert(Entity {
            .entity_id = 0,
            .position = DbVector2{ .x = x, .y = y },
            .mass = @intFromFloat(food_mass),
        });
        _ = try ctx.db.get("food").insert(Food {
            .entity_id = entity.entity_id,
        });
        food_count += 1;
        std.log.info("Spawned food! {}", .{entity.entity_id});
    }
}

pub fn circle_decay(ctx: *spacetime.ReducerContext, _: CircleDecayTimer) !void {
    var circleIter = try ctx.db.get("circle").iter();
    defer circleIter.close();
    while(try circleIter.next()) |circle| {
        var circle_entity = (try ctx
            .db
            .get("entity")
            .col("entity_id")
            .find(.{ .entity_id = circle.entity_id})).?;
        if(circle_entity.mass <= START_PLAYER_MASS) {
            continue;
        }
        circle_entity.mass = @intFromFloat((@as(f32, @floatFromInt(circle_entity.mass)) * 0.99));
        try ctx.db.get("entity").col("entity_id").update(circle_entity);
    }
}

pub fn calculate_center_of_mass(entities: []const Entity) DbVector2 {
    const total_mass: u32 = blk: {
        var sum: u32 = 0;
        for(entities) |entity| {
            sum += entity.mass;
        }
        break :blk sum;
    };
    const center_of_mass: DbVector2 = blk: {
        var sum: DbVector2 = 0;
        for(entities) |entity| {
            sum.x += entity.position.x * @as(f32, @floatFromInt(entity.mass));
            sum.y += entity.position.y * @as(f32, @floatFromInt(entity.mass));
        }
        break :blk sum;
    };
    return center_of_mass / @as(f32, @floatFromInt(total_mass));
}

pub fn circle_recombine(ctx: *spacetime.ReducerContext, timer: CircleRecombineTimer) !void {
    var circles = std.ArrayList(Circle).init(ctx.allocator);
    var circlesIter = try ctx
        .db
        .get("circle")
        .col("player_id")
        .filter(.{ .player_id = timer.player_id });
    defer circlesIter.close();
    while(try circlesIter.next()) |circle| {
        try circles.append(circle);
    }
    var recombining_entities = std.ArrayList(Entity).init(ctx.allocator);
    for(circles.items) |circle| {
        if(@as(f32, @floatFromInt(ctx.timestamp.__timestamp_micros_since_unix_epoch__ - circle.last_split_time.__timestamp_micros_since_unix_epoch__)) >= SPLIT_RECOMBINE_DELAY_SEC) {
            const entity = (try ctx.db
                .get("entity").col("entity_id")
                .find(.{ .entity_id = circle.entity_id })).?;
            try recombining_entities.append(entity);
        }
    }
    if(recombining_entities.items.len <= 1) {
        return; //No circles to recombine
    }

    const base_entity_id = recombining_entities.items[0].entity_id;
    for(1..recombining_entities.items.len) |i| {
        try schedule_consume_entity(ctx, base_entity_id, recombining_entities.items[i].entity_id);
    }
}
