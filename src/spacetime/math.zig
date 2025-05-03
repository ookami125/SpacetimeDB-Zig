pub const DbVector3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn sqr_magnitude(self: @This()) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn magnitude(self: @This()) f32 {
        return @sqrt(self.sqr_magnitude());
    }

    pub fn normalized(self: @This()) DbVector3 {
        const length = self.magnitude();
        return .{
            .x = self.x / length,
            .y = self.y / length,
            .z = self.z / length,
        };
    }

    pub fn scale(self: @This(), val: f32) DbVector3 {
        return .{
            .x = self.x * val,
            .y = self.y * val,
            .z = self.z * val,
        };
    }

    pub fn add(self: @This(), other: DbVector3) DbVector3 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn add_to(self: *@This(), other: DbVector3) void {
        self.x += other.x;
        self.y += other.y;
        self.z += other.z;
    }

    pub fn sub(self: @This(), other: DbVector3) DbVector3 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
        };
    }

    pub fn sub_from(self: *@This(), other: DbVector3) void {
        self.x -= other.x;
        self.y -= other.y;
        self.z -= other.z;
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
