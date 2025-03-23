const std = @import("std");
const utils = @import("utils.zig");
const spacetime = @import("../spacetime.zig");
const console_log = spacetime.console_log;
const TableId = spacetime.TableId;

pub const Str = []const u8;

pub const SumTypeVariant = struct {
    name: ?Str,
    algebraic_type: AlgebraicType,
};

pub const SumType = struct {
    variants: []const SumTypeVariant,
};

pub const ArrayType = struct {
    elem_ty: []const AlgebraicType,
};

pub const AlgebraicType = union(enum) {
    Ref: AlgebraicTypeRef,
    Sum: SumType,
    Product: ProductType,
    Array: ArrayType,
    String: void,
    Bool: void,
    I8: void,
    U8: void,
    I16: void,
    U16: void,
    I32: void,
    U32: void,
    I64: void,
    U64: void,
    I128: void,
    U128: void,
    I256: void,
    U256: void,
    F32: void,
    F64: void,
};

pub const Typespace = struct {
    types: []const AlgebraicType,
};

pub const RawIdentifier = Str;

pub const AlgebraicTypeRef = struct {
    inner: u32,
};

pub const RawIndexAlgorithm = union {
    BTree: []const u16,
    Hash: []const u16,
    Direct: u16,
};

pub const RawIndexDefV9 = struct {
    name: ?Str,
    accessor_name: ?Str,
    algorithm: RawIndexAlgorithm,
};

pub const RawUniqueConstraintDataV9 = union {
    Columns: u16,
};

pub const RawConstraintDataV9 = union {
    unique: RawUniqueConstraintDataV9,
};

pub const RawConstraintDefV9 = struct {
    name: ?Str,
    data: RawConstraintDataV9
};

pub const RawSequenceDefV9 = struct {
    Name: ?Str,
    Column: u16,
    Start: ?i128,
    MinValue: ?i128,
    MaxValue: ?i128,
    Increment: i128
};

pub const RawScheduleDefV9 = struct {
    Name: ?Str,
    ReducerName: Str,
    ScheduledAtColumn: u16
};

pub const TableType = enum {
    System,
    User,
};

pub const TableAccess = enum {
    Public,
    Private,
};

pub const RawTableDefV9 = struct {
    name: RawIdentifier,
    product_type_ref: AlgebraicTypeRef,
    primary_key: []const u16,
    indexes: []const RawIndexDefV9,
    constraints: []const RawConstraintDefV9,
    sequences: []const RawSequenceDefV9,
    schedule: ?RawScheduleDefV9,
    table_type: TableType,
    table_access: TableAccess,
};

pub const ProductTypeElement = struct {
    name: Str,
    algebraic_type: AlgebraicType,
};

pub const ProductType = struct {
    elements: []const ProductTypeElement,
};

pub const Lifecycle = enum {
    Init,
    OnConnect,
    OnDisconnect,
};

fn getStructSize(data: anytype) usize {
    const struct_type = @TypeOf(data);

    const @"spacetime_10.0__table_" = utils.getMemberDefaultType(struct_type, spacetime.MagicStruct);

    const fields = std.meta.fields(@TypeOf(data));
    var size: usize = 0;
    inline for(fields) |field| {
        switch(field.type) {
            []const u8 => {
                const val = @field(data, field.name);
                size += 4 + val.len;
            },
            u32 => {
                size += 4;
            },
            u64 => {
                size += 8;
            },
            f32 => {
                size += 4;
            },
            @"spacetime_10.0__table_" => {},
            else => blk: {
                if(@typeInfo(field.type) == .@"struct" and std.meta.fieldIndex(field.type, spacetime.MagicStruct) != null) {
                    size += getStructSize(@field(data, field.name));
                    break :blk;
                }
                @compileLog(field.type);
                @compileError("Unsupported type in StructSerializer");
            },
        }
    }

    return size;
}

fn getStructData(data: anytype, mem: []u8) []u8 {
    const struct_type = @TypeOf(data);
    const @"spacetime_10.0__table_" = utils.getMemberDefaultType(struct_type, spacetime.MagicStruct);

    const fields = std.meta.fields(@TypeOf(data));
    var offset_mem = mem;
    inline for(fields) |field| {
        switch(field.type) {
            []const u8 => {
                const val = @field(data, field.name);
                std.mem.bytesAsValue(u32, offset_mem[0..4]).* = val.len;
                std.mem.copyForwards(u8, offset_mem[4..], val);
                offset_mem = offset_mem[4 + val.len ..];
            },
            u32 => {
                const val = @field(data, field.name);
                std.mem.bytesAsValue(u32, offset_mem[0..4]).* = val;
                offset_mem = offset_mem[4..];
            },
            u64 => {
                const val = @field(data, field.name);
                std.mem.bytesAsValue(u64, offset_mem[0..4]).* = val;
                offset_mem = offset_mem[8..];
            },
            f32 => {
                const val = @field(data, field.name);
                std.mem.bytesAsValue(f32, offset_mem[0..4]).* = val;
                offset_mem = offset_mem[4..];
            },
            @"spacetime_10.0__table_" => {},
            else => blk: {
                if(@typeInfo(field.type) == .@"struct" and std.meta.fieldIndex(field.type, spacetime.MagicStruct) != null) {
                    offset_mem = getStructData(@field(data, field.name), offset_mem);
                    break :blk;
                }
                @compileLog(field.type);
                @compileError("Unsupported type in StructSerializer");
            },
        }
    }
    return offset_mem;
}

pub fn StructSerializer(struct_type: type) fn(std.mem.Allocator, struct_type) std.mem.Allocator.Error![]u8 {
    return struct {
        pub fn serialize(allocator: std.mem.Allocator, data: struct_type) ![]u8 {
            const size: usize = getStructSize(data);
            const mem = try allocator.alloc(u8, size);
            _ = getStructData(data, mem);
            return mem;
        }
    }.serialize;
} 

pub fn StructDeserializer(struct_type: type) fn(allocator: std.mem.Allocator, *[]const u8) std.mem.Allocator.Error!*struct_type {
    const @"spacetime_10.0__table_" = utils.getMemberDefaultType(struct_type, spacetime.MagicStruct);
    
    return struct {
        pub fn deserialize(allocator: std.mem.Allocator, data: *[]const u8) std.mem.Allocator.Error!*struct_type {
            const ret = try allocator.create(struct_type);
            var offset_mem = data.*;
            const fields = std.meta.fields(struct_type);
            inline for(fields) |field| {
                switch(field.type) {
                    []const u8 => {
                        const len = std.mem.bytesAsValue(u32, offset_mem[0..4]).*;
                        const str = try allocator.dupe(u8, offset_mem[4..(4+len)]);
                        @field(ret.*, field.name) = str;
                        offset_mem = offset_mem[4+len ..];
                    },
                    u32 => {
                        @field(ret.*, field.name) = std.mem.bytesAsValue(u32, offset_mem[0..4]).*;
                        offset_mem = offset_mem[4..];
                    },
                    u64 => {
                        @field(ret.*, field.name) = std.mem.bytesAsValue(u64, offset_mem[0..4]).*;
                        offset_mem = offset_mem[8..];
                    },
                    f32 => {
                        @field(ret.*, field.name) = std.mem.bytesAsValue(f32, offset_mem[0..4]).*;
                        offset_mem = offset_mem[4..];
                    },
                    @"spacetime_10.0__table_" => {},
                    else => blk: {
                        if(@typeInfo(field.type) == .@"struct" and std.meta.fieldIndex(field.type, spacetime.MagicStruct) != null) {
                            @field(ret.*, field.name) = (try StructDeserializer(field.type)(allocator, &offset_mem)).*;
                            break :blk;
                        }
                        @compileLog(field.type);
                        @compileError("Unsupported type in StructDeserializer");
                    },
                }
            }
            data.* = offset_mem;
            return ret;
        }
    }.deserialize;
} 

pub fn Table2ORM(comptime table_type: type) type {
    const table_name = utils.getMemberDefaultValue(table_type, "name");
    const struct_type = utils.getMemberDefaultValue(table_type, "layout");

    return struct {
        allocator: std.mem.Allocator,

        pub const Iter = struct {
            allocator: std.mem.Allocator,
            handle: spacetime.RowIter,
            buffer: [0x20_000]u8 = undefined,
            contents: []u8 = undefined,
            last_ret: i16 = spacetime.OK,
            
            pub fn next(self: *@This()) !?*struct_type {
                var buffer_len: usize = undefined;
                while(true)
                {
                    var ret = self.last_ret;
                    if(self.contents.len == 0) {
                        if(self.handle._inner == spacetime.RowIter.INVALID._inner) {
                            return null;
                        }
                        buffer_len = self.buffer.len;
                        ret = spacetime.row_iter_bsatn_advance(self.handle, @constCast(@ptrCast(&self.buffer)), &buffer_len);
                        self.contents = self.buffer[0..buffer_len];
                        
                        if(ret == spacetime.EXHAUSTED) {
                            self.handle = spacetime.RowIter.INVALID;
                        }
                    }

                    switch(ret) {
                        spacetime.EXHAUSTED, spacetime.OK => {
                            return StructDeserializer(struct_type)(self.allocator, &self.contents);
                        },
                        spacetime.BUFFER_TOO_SMALL => {
                            return error.BUFFER_TOO_SMALL;
                        },
                        spacetime.NO_SUCH_ITER => {
                            return error.NO_SUCH_ITER;
                        },
                        else => {
                            var buffer: [512]u8 = undefined;
                            const msg = try std.fmt.bufPrint(&buffer, "Iter Err: {}!", .{ ret });
                            console_log(2, null, 0, null, 0, 0, msg.ptr, msg.len);
                            @panic("Fix Me!");
                        }
                    }
                }
            }    
        };
        
        pub fn insert(self: @This(), data: struct_type) void {
            var id: TableId = undefined;
            _ = spacetime.table_id_from_name(table_name.ptr, table_name.len, &id);
            const raw_data = StructSerializer(struct_type)(self.allocator, data) catch return;
            defer self.allocator.free(raw_data);
            var raw_data_len: usize = raw_data.len;
            _ = spacetime.datastore_insert_bsatn(id, raw_data.ptr, &raw_data_len);
        }

        pub fn iter(self: @This()) Iter {
            var id: TableId = undefined;
            _ = spacetime.table_id_from_name(table_name.ptr, table_name.len, &id);
            var rowIter: spacetime.RowIter = undefined;
            _ = spacetime.datastore_table_scan_bsatn(id, &rowIter);
            return Iter{
                .allocator = self.allocator,
                .handle = rowIter,
            };
        }
    };
}

pub const Local = struct {
    allocator: std.mem.Allocator,

    pub fn get(self: @This(), table: anytype) Table2ORM(table) {
        return .{
            .allocator = self.allocator,
        };
    }
};

pub const ReducerContext = struct {
    indentity: u256,
    timestamp: u64,
    connection_id: u128,
    db: Local,
};

pub const ReducerFn = fn(*ReducerContext) void;

pub const RawReducerDefV9 = struct {
    name: RawIdentifier,
    params: ProductType,
    lifecycle: ?Lifecycle,
};

pub const RawScopedTypeNameV9 = struct {
    scope: []RawIdentifier,
    name: RawIdentifier,
};

pub const RawTypeDefV9 = struct {
    name: RawScopedTypeNameV9,
    ty: AlgebraicTypeRef,
    custom_ordering: bool,
};

pub const RawMiscModuleExportV9 = enum {
    RESERVED,
};

pub const RawSql = []u8;

pub const RawRowLevelSecurityDefV9 = struct {
    sql: RawSql,
};

pub const RawModuleDefV9 = struct {
    typespace: Typespace,
    tables: []const RawTableDefV9,
    reducers: []const RawReducerDefV9,
    types: []const RawTypeDefV9,
    misc_exports: []const RawMiscModuleExportV9,
    row_level_security: []const RawRowLevelSecurityDefV9,
};
