// Copyright 2025 Tyler Peterson, Licensed under MPL-2.0

const std = @import("std");
const utils = @import("utils.zig");
const spacetime = @import("../spacetime.zig");
const console_log = spacetime.console_log;
const TableId = spacetime.TableId;

const SpacetimeValue = spacetime.SpacetimeValue;
const SpacetimeError = spacetime.SpacetimeError;

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

pub const RawIndexAlgorithm = union(enum) {
    BTree: []const u16,
    Hash: []const u16,
    Direct: u16,
};

pub const RawIndexDefV9 = struct {
    name: ?Str,
    accessor_name: ?Str,
    algorithm: RawIndexAlgorithm,
};

pub const RawUniqueConstraintDataV9 = union(enum) {
    Columns: []const u16,
};

pub const RawConstraintDataV9 = union(enum) {
    unique: RawUniqueConstraintDataV9,
};

pub const RawConstraintDefV9 = struct {
    name: ?Str,
    data: RawConstraintDataV9
};

pub const RawSequenceDefV9 = struct {
    name: ?Str,
    column: u16,
    start: ?i128,
    min_value: ?i128,
    max_value: ?i128,
    increment: i128
};

pub const RawScheduleDefV9 = struct {
    name: ?Str,
    reducer_name: Str,
    scheduled_at_column: u16
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
    None,
};

fn getUnionSize(data: anytype) usize {
    return 1 + switch(data) {
        inline else => |field| getDataSize(field),
    };
}

fn getStructSize(data: anytype) usize {
    var size: usize = 0;
    inline for(std.meta.fields(@TypeOf(data))) |field| {
        size += getDataSize(@field(data, field.name));
    }
    return size;
}

fn getDataSize(data: anytype) usize {
    return switch(@TypeOf(data)) {
        []const u8 => 4 + data.len,
        i8, u8, i16, u16, i32, u32,
        i64, u64, i128, u128, i256, u256,
        f32, f64 => |data_type| @sizeOf(data_type),
        else => |data_type| switch(@typeInfo(data_type)) {
            .@"struct" => getStructSize(data),
            .@"union" => getUnionSize(data),
            .@"enum" => @sizeOf(data_type),
            .@"enum_literal" => @compileError("enum literals can't be supported without the type info"),
            .@"optional" => 1 + getDataSize(data),
            else => {
                @compileLog(data_type);
                @compileError("Unsupported type in getStructSize");
            },
        },
    };
}

fn getUnionData(data: anytype, mem: *[]u8) void {
    const tag: u8 = @intFromEnum(data);
    appendValue(tag, mem);
    switch(data) {
        inline else => |field| {
            appendValue(field, mem);
        },
    }
}

fn getStructData(data: anytype, mem: *[]u8) void {
    const fields = std.meta.fields(@TypeOf(data));
    inline for(fields) |field| {
        appendValue(@field(data, field.name), mem);
    }
}

fn appendValue(data: anytype, mem: *[]u8) void {
    const data_type = @TypeOf(data);
    switch(data_type) {
        []const u8 => {
            std.mem.bytesAsValue(u32, mem.*[0..4]).* = data.len;
            std.mem.copyForwards(u8, mem.*[4..], data);
            mem.* = mem.*[4 + data.len ..];
        },
        i8, u8, i16, u16, i32, u32,
        i64, u64, i128, u128, i256, u256,
        f32, f64 => {
            std.mem.bytesAsValue(data_type, mem.*[0..@sizeOf(data_type)]).* = data;
            mem.* = mem.*[@sizeOf(data_type)..];
        },
        else => blk: {
            if(@typeInfo(data_type) == .@"struct") {
                getStructData(data, mem);
                break :blk;
            } else if(@typeInfo(data_type) == .@"union") {
                getUnionData(data, mem);
                break :blk;
            } else if(@typeInfo(data_type) == .@"optional") {
                mem.*[0] = @intFromBool(data == null);
                mem.* = mem.*[1..];
                if(data != null) {
                    appendValue(data.?, mem);
                }
                break :blk;
            } else if(@typeInfo(data_type) == .@"enum") {
                std.mem.bytesAsValue(data_type, mem.*[0..@sizeOf(data_type)]).* = data;
                mem.* = mem.*[@sizeOf(data_type)..];
                break :blk;
            }
            @compileLog(data_type);
            @compileError("failed to append type!");
        }
    }
}

pub fn StructSerializer(struct_type: type) fn(std.mem.Allocator, struct_type) std.mem.Allocator.Error![]u8 {
    return struct {
        pub fn serialize(allocator: std.mem.Allocator, data: struct_type) ![]u8 {
            const size: usize = switch(@typeInfo(@TypeOf(data))) {
                .@"struct" => getStructSize(data),
                else => @compileError("A table schema has to be a struct!"),
            };
            const mem = try allocator.alloc(u8, size);
            var offset_mem = mem;
            _ = getStructData(data, &offset_mem);
            return mem;
        }
    }.serialize;
} 

pub fn UnionDeserializer(union_type: type) fn(allocator: std.mem.Allocator, *[]const u8) std.mem.Allocator.Error!*union_type {
    return struct {
        pub fn deserialize(allocator: std.mem.Allocator, data: *[]const u8) std.mem.Allocator.Error!*union_type {
            const ret = try allocator.create(union_type);
            var offset_mem = data.*;
            
            const tagType = u8;

            const tag: std.meta.Tag(union_type) = @enumFromInt(std.mem.bytesAsValue(tagType, offset_mem[0..@sizeOf(tagType)]).*);
            offset_mem = offset_mem[@sizeOf(tagType)..];
            switch(tag) {
                inline else => |union_field| {
                    const field = std.meta.fields(union_type)[@intFromEnum(union_field)];
                    switch(field.type) {
                        []const u8 => {
                            const len = std.mem.bytesAsValue(u32, offset_mem[0..4]).*;
                            const str = try allocator.dupe(u8, offset_mem[4..(4+len)]);
                            @field(ret.*, field.name) = str;
                            offset_mem = offset_mem[4+len ..];
                        },
                        i8, u8, i16, u16, i32, u32,
                        i64, u64, i128, u128, i256, u256,
                        f32, f64 => {
                            @field(ret.*, field.name) = std.mem.bytesAsValue(field.type, offset_mem[0..@sizeOf(field.type)]).*;
                            offset_mem = offset_mem[@sizeOf(field.type)..];
                        },
                        else => blk: {
                            if(@typeInfo(field.type) == .@"struct") {
                                @field(ret.*, field.name) = (try StructDeserializer(field.type)(allocator, &offset_mem)).*;
                                break :blk;
                            } else if(@typeInfo(field.type) == .@"union") {
                                @field(ret.*, field.name) = (try UnionDeserializer(field.type)(allocator, &offset_mem)).*;
                                break :blk;
                            }
                            @compileLog(field.type);
                            @compileError("Unsupported type in StructDeserializer");
                        },
                    }
                }
            }

            data.* = offset_mem;
            return ret;
        }
    }.deserialize;
} 

pub fn StructDeserializer(struct_type: type) fn(allocator: std.mem.Allocator, *[]u8) std.mem.Allocator.Error!struct_type {
    return struct {
        pub fn deserialize(allocator: std.mem.Allocator, data: *[]u8) std.mem.Allocator.Error!struct_type {
            var ret: struct_type = undefined;
            var offset_mem = data.*;
            const fields = std.meta.fields(struct_type);
            inline for(fields) |field| {
                switch(field.type) {
                    []const u8 => {
                        const len = std.mem.bytesAsValue(u32, offset_mem[0..4]).*;
                        const str = try allocator.dupe(u8, offset_mem[4..(4+len)]);
                        @field(ret, field.name) = str;
                        offset_mem = offset_mem[4+len ..];
                    },
                    i8, u8, i16, u16, i32, u32,
                    i64, u64, i128, u128, i256, u256,
                    f32, f64  => {
                        @field(ret, field.name) = std.mem.bytesAsValue(field.type, offset_mem[0..@sizeOf(field.type)]).*;
                        offset_mem = offset_mem[@sizeOf(field.type)..];
                    },
                    else => blk: {
                        if(@typeInfo(field.type) == .@"struct") {
                            @field(ret, field.name) = try StructDeserializer(field.type)(allocator, &offset_mem);
                            break :blk;
                        } else if(@typeInfo(field.type) == .@"union") {
                            @field(ret, field.name) = try UnionDeserializer(field.type)(allocator, &offset_mem);
                            break :blk;
                        }
                        @compileLog(field.type);
                        @compileError("Unsupported type in StructDeserializer");
                    },
                }
            }
            data.* = offset_mem;
            //std.log.debug("StructDeserializer Ended!", .{});
            return ret;
        }
    }.deserialize;
} 

pub const BoundVariant = enum(u8)
{
    Inclusive = 0,
    Exclusive = 1,
    Unbounded = 2,
};

noinline fn lineInfo() usize {
    return @returnAddress();
}

pub fn Iter(struct_type: type) type {
    return struct {
        allocator: std.mem.Allocator,
        handle: spacetime.RowIter,
        buffer: []u8,
        contents: []u8,
        last_ret: SpacetimeValue = .OK,
        inited: bool = false,
        
        pub fn init(allocator: std.mem.Allocator, rowIter: spacetime.RowIter) !@This() {
            const buffer = try allocator.alloc(u8, 0x20_000);
            return .{
                .allocator = allocator,
                .handle = rowIter,
                .buffer = buffer,
                .contents = buffer[0..0],
                .inited = true,
            };
        }

        pub fn next(self: *@This()) spacetime.ReducerError!?struct_type {
            var buffer_len: usize = undefined;
            var ret: spacetime.SpacetimeValue = self.last_ret;
            blk: while(true) {
                if(self.contents.len == 0) {
                    if(self.handle._inner == spacetime.RowIter.INVALID._inner) {
                        return null;
                    }

                    buffer_len = self.buffer.len;
                    ret = spacetime.retMap(spacetime.row_iter_bsatn_advance(self.handle, self.buffer.ptr, &buffer_len)) catch |err| {
                        switch(err) {
                            SpacetimeError.BUFFER_TOO_SMALL => {
                                self.buffer = try self.allocator.realloc(self.buffer, buffer_len);
                                continue :blk;
                            },
                            SpacetimeError.NO_SUCH_ITER => {
                                return SpacetimeError.NO_SUCH_ITER;
                            },
                            else => {
                                return SpacetimeError.UNKNOWN;
                            }
                        }
                    };
                    
                    self.contents = self.buffer[0..buffer_len];
                    
                    if(ret == .EXHAUSTED) {
                        self.handle = spacetime.RowIter.INVALID;
                    }
                    self.last_ret = ret;
                }
                if(self.contents.len == 0) {
                    return null;
                }
                
                var offset = self.contents;
                const retValue = try StructDeserializer(struct_type)(self.allocator, &offset);
                self.contents = offset;

                return retValue;
            }
        }

        pub fn close(self: *@This()) void {
            if (self.handle.invalid())
            {
                _ = spacetime.row_iter_bsatn_close(self.handle);
                self.handle = spacetime.RowIter.INVALID;
            }
            self.contents = undefined;
            self.allocator.free(self.buffer);
        }
    };
}

pub fn Column2ORM(comptime table_name: []const u8, comptime column_name: [:0]const u8) type {
    const table = blk: {
        for(spacetime.globalSpec.tables) |table| {
            if(std.mem.eql(u8, table_name, table.name)) {
                break :blk table;
            }
        }
        @compileError("Table " ++ table_name ++ " does not exist!");
    };
    const struct_type = table.schema;
    const column_type = utils.getMemberDefaultType(struct_type, column_name);

    const wrapped_type = @Type(.{
        .@"struct" = std.builtin.Type.Struct{
            .backing_integer = null,
            .decls = &.{},
            .fields = &.{
                std.builtin.Type.StructField{
                    .alignment = @alignOf(column_type),
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .name = column_name,
                    .type = column_type,
                }
            },
            .is_tuple = false,
            .layout = .auto,
        }
    });
    
    return struct {
        allocator: std.mem.Allocator,

        pub fn filter(self: @This(), val: wrapped_type) !Iter(struct_type) {
            const temp_name: []const u8 = comptime table_name ++ "_" ++ column_name ++ "_idx_btree";
            var id = spacetime.IndexId{ ._inner = std.math.maxInt(u32)};
            const err = try spacetime.retMap(spacetime.index_id_from_name(temp_name.ptr, temp_name.len, &id));
            _ = err;
            //std.log.debug("index_id_from_name({}): {x}", .{err, id._inner});

            const nVal: struct{ bounds: BoundVariant, val: wrapped_type } = .{
                .bounds = .Inclusive,
                .val = val,
            };

            const size: usize = getStructSize(nVal);
            const mem = try self.allocator.alignedAlloc(u8, 1, size);
            defer self.allocator.free(mem);
            var offset_mem = mem;
            getStructData(nVal, &offset_mem);

            const data = mem[0..size];
            const rstart: []u8 = data[0..];
            const rend: []u8 = data[0..];

            var rowIter: spacetime.RowIter = undefined;

            _ = try spacetime.retMap(spacetime.datastore_index_scan_range_bsatn(
                id,
                data.ptr, 0,
                spacetime.ColId{ ._inner = 0},
                rstart.ptr, rstart.len,
                rend.ptr, rend.len,
                &rowIter
            ));

            return Iter(struct_type).init(self.allocator, rowIter);
        }

        pub fn find(self: @This(), val: wrapped_type) !?struct_type {
            var iter = try self.filter(val);
            return try iter.next();
        }

        pub fn delete(self: @This(), val: wrapped_type) !void {
            const temp_name: []const u8 = table_name ++ "_" ++ column_name ++ "_idx_btree";
            var id = spacetime.IndexId{ ._inner = std.math.maxInt(u32)};
            _ = spacetime.index_id_from_name(temp_name.ptr, temp_name.len, &id);

            const nVal: struct{ bounds: BoundVariant, val: wrapped_type } = .{
                .bounds = .Inclusive,
                .val = val,
            };

            const size: usize = getStructSize(nVal);
            const mem = try self.allocator.alloc(u8, size);
            defer self.allocator.free(mem);
            var offset_mem = mem;
            getStructData(nVal, &offset_mem);

            const data = mem[0..size];
            const rstart: []u8 = data[0..];
            const rend: []u8 = data[0..];

            var deleted_fields: u32 = undefined;

            _ = spacetime.datastore_delete_by_index_scan_range_bsatn(
                id,
                data.ptr, 0,
                spacetime.ColId{ ._inner = 0},
                rstart.ptr, rstart.len,
                rend.ptr, rend.len,
                &deleted_fields
            );
        }

        pub fn update(self: @This(), val: struct_type) !void {
            var table_id: TableId = undefined;
            _ = spacetime.table_id_from_name(table_name.ptr, table_name.len, &table_id);

            const temp_name: []const u8 = table_name ++ "_" ++ column_name ++ "_idx_btree";
            var index_id = spacetime.IndexId{ ._inner = std.math.maxInt(u32) };
            _ = spacetime.index_id_from_name(temp_name.ptr, temp_name.len, &index_id);

            const size: usize = getStructSize(val);
            const mem = try self.allocator.alloc(u8, size);
            defer self.allocator.free(mem);
            var offset_mem = mem;
            getStructData(val, &offset_mem);

            const data = mem[0..size];
            var data_len = data.len;
            _ = spacetime.datastore_update_bsatn(
                table_id,
                index_id,
                data.ptr,
                &data_len
            );
        }
    };
}

pub fn AutoIncStruct(base: type, autoincs: []const [:0]const u8) type {
    return @Type(.{
        .@"struct" = std.builtin.Type.Struct{
            .backing_integer = null,
            .decls = &.{},
            .is_tuple = false,
            .layout = .auto,
            .fields = blk: {
                var fields: []const std.builtin.Type.StructField = &.{};
                for(autoincs) |autoinc| {
                    const member_type = utils.getMemberDefaultType(base, autoinc);
                    fields = fields ++ &[_]std.builtin.Type.StructField{
                        std.builtin.Type.StructField{
                            .is_comptime = false,
                            .name = autoinc,
                            .default_value_ptr = null,
                            .type = member_type,
                            .alignment = 0,
                        }
                    };
                }

                break :blk fields;
            }
        }
    });
}

pub fn Table2ORM(comptime table_name: []const u8) type {
    const table = blk: {
        for(spacetime.globalSpec.tables) |table| {
            if(std.mem.eql(u8, table_name, table.name)) {
                break :blk table;
            }
        }
        @compileError("Table " ++ table_name ++ " not found!");
    };
    const struct_type = table.schema;

    const autoinc_return_type = AutoIncStruct(struct_type, table.attribs.autoinc orelse &.{});

    return struct {
        allocator: std.mem.Allocator,

        pub fn insert(self: @This(), data: struct_type) !struct_type {
            var id: TableId = undefined;
            _ = spacetime.table_id_from_name(table_name.ptr, table_name.len, &id);
            var raw_data = try StructSerializer(struct_type)(self.allocator, data);
            defer self.allocator.free(raw_data);
            var raw_data_len: usize = raw_data.len;
            _ = spacetime.datastore_insert_bsatn(id, raw_data.ptr, &raw_data_len);

            var data_copy = data;
            const out = try StructDeserializer(autoinc_return_type)(self.allocator, &raw_data);
            inline for(std.meta.fields(autoinc_return_type)) |field| {
                @field(data_copy, field.name) = @field(out, field.name);
            }

            return data_copy;
        }

        pub fn iter(self: @This()) !Iter(struct_type) {
            var id: TableId = undefined;
            _ = spacetime.table_id_from_name(table_name.ptr, table_name.len, &id);
            var rowIter: spacetime.RowIter = undefined;
            _ = spacetime.datastore_table_scan_bsatn(id, &rowIter);
            return Iter(struct_type).init(self.allocator, rowIter);
        }

        pub fn col(self: @This(), comptime column_name: [:0]const u8) Column2ORM(table_name, column_name) {
            return .{
                .allocator = self.allocator,
            };
        }

        pub fn count(self: @This()) !u64 {
            _ = self;
            var id: TableId = undefined;
            _ = spacetime.table_id_from_name(table_name.ptr, table_name.len, &id);
            var val: u64 = undefined;
            _ = try spacetime.retMap(spacetime.datastore_table_row_count(id, &val));
            return val;
        }
    };
}

pub const Local = struct {
    allocator: std.mem.Allocator,
    frame_allocator: std.mem.Allocator,

    pub fn get(self: @This(), comptime table: []const u8) Table2ORM(table) {
        return .{
            .allocator = self.frame_allocator,
        };
    }
};

pub const ReducerContext = struct {
    allocator: std.mem.Allocator,
    sender: spacetime.Identity,
    timestamp: spacetime.Timestamp,
    connection_id: spacetime.ConnectionId,
    db: Local,
    rng: std.Random.DefaultPrng = std.Random.DefaultPrng.init(0),
};

pub const ReducerFn = fn(*ReducerContext) void;

pub const RawReducerDefV9 = struct {
    name: RawIdentifier,
    params: ProductType,
    lifecycle: Lifecycle,
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

pub const RawSql = Str;

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
