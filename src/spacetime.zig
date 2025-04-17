const std = @import("std");
const utils = @import("spacetime/utils.zig");

pub const st_types = @import("spacetime/types.zig");
pub const serializer = @import("spacetime/serializer.zig");

pub const SumTypeVariant = st_types.SumTypeVariant;
pub const SumType = st_types.SumType;
pub const ArrayType = st_types.ArrayType;
pub const AlgebraicType = st_types.AlgebraicType;
pub const Typespace = st_types.Typespace;
pub const RawIdentifier = st_types.RawIdentifier;
pub const AlgebraicTypeRef = st_types.AlgebraicTypeRef;
pub const RawIndexAlgorithm = st_types.RawIndexAlgorithm;
pub const RawIndexDefV9 = st_types.RawIndexDefV9;
pub const RawUniqueConstraintDataV9 = st_types.RawUniqueConstraintDataV9;
pub const RawConstraintDataV9 = st_types.RawConstraintDataV9;
pub const RawConstraintDefV9 = st_types.RawConstraintDefV9;
pub const RawSequenceDefV9 = st_types.RawSequenceDefV9;
pub const RawScheduleDefV9 = st_types.RawScheduleDefV9;
pub const TableType = st_types.TableType;
pub const TableAccess = st_types.TableAccess;
pub const RawTableDefV9 = st_types.RawTableDefV9;
pub const ProductTypeElement = st_types.ProductTypeElement;
pub const ProductType = st_types.ProductType;
pub const Lifecycle = st_types.Lifecycle;
pub const ReducerContext = st_types.ReducerContext;
pub const ReducerFn = st_types.ReducerFn;
pub const RawReducerDefV9 = st_types.RawReducerDefV9;
pub const RawScopedTypeNameV9 = st_types.RawScopedTypeNameV9;
pub const RawTypeDefV9 = st_types.RawTypeDefV9;
pub const RawMiscModuleExportV9 = st_types.RawMiscModuleExportV9;
pub const RawSql = st_types.RawSql;
pub const RawRowLevelSecurityDefV9 = st_types.RawRowLevelSecurityDefV9;
pub const RawModuleDefV9 = st_types.RawModuleDefV9;

pub const serialize_module = serializer.serialize_module;

pub extern "spacetime_10.0" fn console_log(
    level: u8,
    target_ptr: [*c]const u8,
    target_len: usize,
    filename_ptr: [*c]const u8,
    filename_len: usize,
    line_number: u32,
    message_ptr: [*c]const u8,
    message_len: usize,
) void;

pub fn logFn(comptime level: std.log.Level, comptime _: @TypeOf(.enum_literal), comptime fmt: []const u8, args: anytype) void {
    const allocator = std.heap.wasm_allocator;
    const msg = std.fmt.allocPrint(allocator, fmt, args) catch "debug_print allocation failure!";
    defer allocator.free(msg);
    const outLevel = switch(level) {
        .err => 0,
        .warn => 1,
        .info => 2,
        .debug => 3,
    };
    console_log(outLevel, null, 0, null, 0, 0, msg.ptr, msg.len);
    
}

pub const BytesSink = extern struct { inner: u32 };
pub const BytesSource = extern struct { inner: u32 };
pub const TableId = extern struct { _inner: u32, };
pub const RowIter = extern struct {
    _inner: u32,
    pub const INVALID = RowIter{ ._inner = 0};
    pub fn invalid(self: @This()) bool {
        return self._inner == 0;
    }
};
pub const IndexId = extern struct{ _inner: u32 };
pub const ColId = extern struct { _inner: u16 };

pub const Identity = struct {
    __identity__: u256,
};

pub const Timestamp = struct {
    __timestamp_micros_since_unix_epoch__: i64,

    pub fn DurationSince(self: @This(), other: @This()) TimeDuration {
        return .{
            .__time_duration_micros__ = other.__timestamp_micros_since_unix_epoch__ - self.__timestamp_micros_since_unix_epoch__,
        };
    }
};

pub const TimeUnit = enum {
    Seconds,
};

pub const TimeDuration = struct {
    __time_duration_micros__: i64,

    pub fn as_f32(self: @This(), unit: TimeUnit) f32 {
        return switch(unit) {
            .Seconds => @as(f32, @floatFromInt(self.__time_duration_micros__)) / std.time.us_per_s,
        };
    }
};

pub const ScheduleAt = union(enum){
    Interval: TimeDuration,
    Time: Timestamp,

    pub fn durationSecs(ctx: *ReducerContext, secs: f32) ScheduleAt {
        return .{
            .Time = .{
                .__timestamp_micros_since_unix_epoch__ =
                    ctx.timestamp.__timestamp_micros_since_unix_epoch__ +
                    @as(i64, @intFromFloat(secs * std.time.us_per_s)),
            }
        };
    }
};

pub const ConnectionId = struct {
    __connection_id__: u128,
};

pub const SpacetimeValue = enum(u1) {
    OK = 0,
    EXHAUSTED = 1,
};

pub const SpacetimeError = error {
    UNKNOWN,
    HOST_CALL_FAILURE,
    NOT_IN_TRANSACTION,
    BSATN_DECODE_ERROR,
    NO_SUCH_TABLE,
    NO_SUCH_INDEX,
    NO_SUCH_ITER,
    NO_SUCH_BYTES,
    NO_SPACE,
    BUFFER_TOO_SMALL,
    UNIQUE_ALREADY_EXISTS,
    SCHEDULE_AT_DELAY_TOO_LONG,
    INDEX_NOT_UNIQUE,
    NO_SUCH_ROW,
};

pub extern "spacetime_10.0" fn bytes_sink_write(sink: BytesSink, buffer_ptr: [*c]const u8, buffer_len_ptr: *usize) u16;
pub extern "spacetime_10.0" fn bytes_source_read(source: BytesSource, buffer_ptr: [*c]u8, buffer_len_ptr: *usize) i16;

pub extern "spacetime_10.0" fn table_id_from_name(name: [*c]const u8, name_len: usize, out: *TableId) u16;
pub extern "spacetime_10.0" fn index_id_from_name(name_ptr: [*c]const u8, name_len: usize, out: *IndexId) u16;

pub extern "spacetime_10.0" fn datastore_insert_bsatn(table_id: TableId, row_ptr: [*c]const u8, row_len_ptr: *usize) u16;
pub extern "spacetime_10.0" fn row_iter_bsatn_advance(iter: RowIter, buffer_ptr: [*c]u8, buffer_len_ptr: *usize) i16;

pub extern "spacetime_10.0" fn datastore_table_scan_bsatn(table_id: TableId, out: [*c]RowIter) u16;
pub extern "spacetime_10.0" fn datastore_index_scan_range_bsatn( index_id: IndexId, prefix_ptr: [*c]const u8, prefix_len: usize, prefix_elems: ColId, rstart_ptr: [*c]const u8, rstart_len: usize, rend_ptr: [*c]const u8, rend_len: usize, out: *RowIter) u16;
pub extern "spacetime_10.0" fn row_iter_bsatn_close(iter: RowIter) u16;

pub extern "spacetime_10.0" fn datastore_delete_by_index_scan_range_bsatn(index_id: IndexId, prefix_ptr: [*c]const u8, prefix_len: usize, prefix_elems: ColId, rstart_ptr: [*c]const u8, rstart_len: usize, rend_ptr: [*c]const u8, rend_len: usize, out: [*c]u32) u16;
pub extern "spacetime_10.0" fn datastore_update_bsatn(table_id: TableId, index_id: IndexId, row_ptr: [*c]u8, row_len_ptr: [*c]usize) u16;

pub extern "spacetime_10.0" fn datastore_table_row_count(table_id: TableId, out: [*c]u64) u16;

pub fn retMap(errVal: i17) !SpacetimeValue {
    return switch(errVal) {
        -1 => SpacetimeValue.EXHAUSTED,
        0 => SpacetimeValue.OK,
        1 => SpacetimeError.HOST_CALL_FAILURE,
        2 => SpacetimeError.NOT_IN_TRANSACTION,
        3 => SpacetimeError.BSATN_DECODE_ERROR,
        4 => SpacetimeError.NO_SUCH_TABLE,
        5 => SpacetimeError.NO_SUCH_INDEX,
        6 => SpacetimeError.NO_SUCH_ITER,
        8 => SpacetimeError.NO_SUCH_BYTES,
        9 => SpacetimeError.NO_SPACE,
        11 => SpacetimeError.BUFFER_TOO_SMALL,
        12 => SpacetimeError.UNIQUE_ALREADY_EXISTS,
        13 => SpacetimeError.SCHEDULE_AT_DELAY_TOO_LONG,
        14 => SpacetimeError.INDEX_NOT_UNIQUE,
        15 => SpacetimeError.NO_SUCH_ROW,
        else => unreachable,
    };
}

pub const ReducerError = SpacetimeError || std.mem.Allocator.Error || std.fmt.BufPrintError;

pub fn read_bytes_source(source: BytesSource, buf: []u8) ![]u8 {
    var buf_len = buf.len;
    _ = try retMap(bytes_source_read(source, @ptrCast(buf), &buf_len));
    return buf[0..buf_len];
}

pub fn write_to_sink(sink: BytesSink, _buf: []const u8) !void {
    var buf: []const u8 = _buf;
    while(true) {
        const len: *usize = &buf.len;
        _ = try retMap(bytes_sink_write(sink, buf.ptr, len));
        buf = buf[len.*..];
        if(buf.len == 0) {
            break;
        }
    }
}

pub const StructFieldDecl = struct {
    name: [:0]const u8,
    type: type,
    isPrimaryKey: bool = false,
    autoInc: bool = false,
};

pub const StructDecl = struct {
    name: []const u8,
    fields: []const StructFieldDecl,
};

fn spacetimeType2ZigType(t: AlgebraicType) type {
    return switch (t) {
        .String => []const u8,
        .Bool => bool,
        .I8 => i8,
        .U8 => u8,
        .I16 => i16,
        .U16 => u16,
        .I32 => i32,
        .U32 => u32,
        .I64 => i64,
        .U64 => u64,
        .I128 => i128,
        .U128 => u128,
        .I256 => i256,
        .U256 => u256,
        .F32 => f32,
        .F64 => f64,
        else => {
            @compileLog(t);
            @compileError("spacetimeType2ZigType: unsupported type!");
        },
    };
}

const StructFieldImpl = struct {
    name: []const u8,
    type: AlgebraicType,
};

pub fn readArg(allocator: std.mem.Allocator, args: BytesSource, comptime t: type) !t {
    switch(t) {
        []const u8 => {
            var maxbuf: [4]u8 = undefined;
            const len_buf = try read_bytes_source(args, &maxbuf);
            const len: usize = std.mem.bytesToValue(u32, len_buf);
            const string_buf = try allocator.alloc(u8, len);
            return try read_bytes_source(args, string_buf);
        },
        i8, u8, i16, u16, i32, u32,
        i64, u64, i128, u128, i256, u256,
        f32, f64 => {
            const read_type = t;
            var maxbuf: [@sizeOf(read_type)]u8 = undefined;
            const len_buf = try read_bytes_source(args, &maxbuf);
            return std.mem.bytesToValue(t, len_buf);
        },
        else => {
            switch(@typeInfo(t)) {
                .@"struct" => {
                    const fields = std.meta.fields(t);
                    var temp: t = undefined;
                    inline for(fields) |field| {
                        @field(temp, field.name) = try readArg(allocator, args, field.type);
                    }
                    return temp;
                },
                .@"union" => {
                    const tagType = std.meta.Tag(t);
                    const intType = u8;
                    const tag: tagType = @enumFromInt(try readArg(allocator, args, intType));
                    switch(tag) {
                        inline else => |tag_field| {
                            var temp: t = @unionInit(t, @tagName(tag_field), undefined);
                            const field = std.meta.fields(t)[@intFromEnum(tag_field)];
                            @field(temp, field.name) = (try readArg(allocator, args, field.type));
                            return temp;
                        }
                    }
                },
                else => {
                    @compileLog(t);
                    @compileError("unsupported type in readArg!");
                }
            }
        },
    }
}

pub fn zigTypeToSpacetimeType(comptime param: ?type) AlgebraicType {
    if(param == null) @compileError("Null parameter type passed to zigParamsToSpacetimeParams");
    return switch(param.?) {
        []const u8 => .{ .String = {} },
        i32 => .{ .I32 = {}, },
        i64 => .{ .I64 = {}, },
        i128 => .{ .I128 = {}, },
        i256 => .{ .I258 = {}, },
        u32 => .{ .U32 = {}, },
        u64 => .{ .U64 = {}, },
        u128 => .{ .U128 = {}, },
        u256 => .{ .U256 = {}, },
        f32 => .{ .F32 = {}, },
        f64 => .{ .F64 = {}, },
        else => blk: {
            if(@typeInfo(param.?) == .@"struct") {
                var elements: []const ProductTypeElement = &.{};
                const fields = std.meta.fields(param.?);
                for(fields) |field| {
                    elements = elements ++ &[_]ProductTypeElement{
                        ProductTypeElement{
                            .name = field.name,
                            .algebraic_type = zigTypeToSpacetimeType(field.type),
                        },
                    };
                }

                break :blk .{
                    .Product = ProductType{
                        .elements = elements
                    }
                };
            } else if(@typeInfo(param.?) == .@"union") {
                var variants: []const SumTypeVariant = &.{};
                const fields = std.meta.fields(param.?);
                for(fields) |field| {
                    variants = variants ++ &[_]SumTypeVariant{
                        SumTypeVariant{
                            .name = field.name,
                            .algebraic_type = zigTypeToSpacetimeType(field.type),
                        },
                    };
                }

                break :blk .{
                    .Sum = SumType{
                        .variants = variants
                    }
                };
            }
            @compileLog(param.?);
            @compileError("Unmatched type passed to zigTypeToSpacetimeType!");
        },
    };
}

const StructImpl = struct {
    name: []const u8,
    fields: []const StructFieldImpl,
};

pub fn addStructImpl(comptime structImpls: *[]const StructImpl, layout: anytype) u32 {
    const name = blk: {
        var temp: []const u8 = @typeName(layout);
        if(std.mem.lastIndexOf(u8, temp, ".")) |idx|
            temp = temp[idx+1..];
        break :blk temp;
    };

    //FIXME: Search for existing structImpl of provided layout. I think the current might work, but I don't trust it.
    inline for(structImpls.*, 0..) |structImpl, i| {
        @setEvalBranchQuota(structImpl.name.len * 100);
        if(std.mem.eql(u8, structImpl.name, name)) {
            return i;
        }
    }
    
    const fields = std.meta.fields(layout);
    var members: []const StructFieldImpl = &[_]StructFieldImpl{};
    inline for(fields) |field| {
        if(@typeInfo(field.type) == .@"struct") {
            members = members ++ &[_]StructFieldImpl{
                .{
                    .name = field.name,
                    .type = .{
                        .Ref = .{
                            .inner = addStructImpl(structImpls, field.type),
                        }
                    }
                }
            };
        } else if(@typeInfo(field.type) == .@"union") {
            var variants: []const SumTypeVariant = &[_]SumTypeVariant{};
            _ = &variants;
            
            const unionFields = std.meta.fields(field.type);
            inline for(unionFields) |unionField| {
                variants = variants ++ &[_]SumTypeVariant{
                    SumTypeVariant{
                        .name = unionField.name,
                        .algebraic_type = zigTypeToSpacetimeType(unionField.type),
                    }
                };
            }
            members = members ++ &[_]StructFieldImpl{
                .{
                    .name = field.name,
                    .type = .{
                        .Sum = .{
                            .variants = variants,
                        }
                    }
                }
            };
        } else {
            members = members ++ &[_]StructFieldImpl{
                .{
                    .name = field.name,
                    .type = zigTypeToSpacetimeType(field.type),
                }
            };
        }
        members = members ++ &[_]StructFieldImpl{};
    }
    structImpls.* = structImpls.* ++ &[_]StructImpl{
        .{
            .name = name,
            .fields = members,
        },
    };
    return structImpls.len - 1;
}

pub fn getStructImplOrType(structImpls: []const StructImpl, layout: type) AlgebraicType {
    const name = blk: {
        var temp: []const u8 = @typeName(layout);
        if(std.mem.lastIndexOf(u8, temp, ".")) |idx|
            temp = temp[idx+1..];
        break :blk temp;
    };
    
    @setEvalBranchQuota(structImpls.len * 100);
    inline for(structImpls, 0..) |structImpl, i| {
        if(std.mem.eql(u8, structImpl.name, name)) {
            return .{
                .Ref = AlgebraicTypeRef{
                    .inner = i,
                },
            };
        }
    }

    return zigTypeToSpacetimeType(layout);
}

pub fn callReducer(comptime mdef: []const SpecReducer, comptime id: usize, args: anytype) ReducerError!void {
    inline for(mdef, 0..) |field, i| {
        if(id == i) {
            const func = field.func_type;
            if(std.meta.fields(@TypeOf(args)).len == @typeInfo(func).@"fn".params.len) {
                const func_val: func = @as(*const func, @ptrCast(field.func)).*;
                return @call(.auto, func_val, args);
            }
        
            const name: []const u8 = field.name;
            std.log.err("invalid number of args passed to {s}, expected {} got {}", .{name, @typeInfo(func).@"fn".params.len, std.meta.fields(@TypeOf(args)).len});
            @panic("invalid number of args passed to func");
        }
    }
}

pub fn PrintModule(data: anytype) void {
    std.log.debug("\"{s}\": {{", .{@typeName(@TypeOf(data))});
    switch(@TypeOf(data)) {
        RawModuleDefV9 => {
            PrintModule(data.typespace);
            PrintModule(data.tables);
            PrintModule(data.reducers);
            PrintModule(data.types);
        },
        Typespace => {
            for(data.types) |_type| {
                PrintModule(_type);
            }
        },
        AlgebraicType => {
            switch(data) {
                .Ref => PrintModule(data.Ref),
                .Product => PrintModule(data.Product),
                else => {},
            }
        },
        AlgebraicTypeRef => {
            PrintModule(data.inner);
        },
        ProductType => {
            for(data.elements) |elem| {
                PrintModule(elem);
            }
        },
        ProductTypeElement => {
            PrintModule(data.name);
            PrintModule(data.algebraic_type);
        },
        []const RawTableDefV9 => {
            for(data) |elem| {
                PrintModule(elem);
            }
        },
        []const RawTypeDefV9 => {
            for(data) |elem| {
                PrintModule(elem);
            }
        },
        RawTypeDefV9 => {
            PrintModule(data.name);
            PrintModule(data.ty);
        },
        RawScopedTypeNameV9 => {
            PrintModule(data.scope);
            PrintModule(data.name);
        },
        []const RawReducerDefV9 => {
            for(data) |elem| {
                PrintModule(elem);
            }
        },
        RawReducerDefV9 => {
            PrintModule(data.lifecycle);
            PrintModule(data.name);
            PrintModule(data.params);
        },
        Lifecycle => {
            std.log.debug("\"{any}\"", .{data});
        },
        [][]const u8 => {
            for(data) |elem| {
                PrintModule(elem);
            }
        },
        []const u8 => {
            std.log.debug("\"{s}\"", .{data});
        },
        u32 => {
            std.log.debug("{}", .{data});
        },
        else => {
            std.log.debug("\"...\"", .{});
        },
    }
    std.log.debug("}},", .{});
}

pub const Param = struct {
    name: []const u8,
};

pub const SpecReducer = struct {
    name: []const u8,
    lifecycle: Lifecycle = .None,
    params: []const [:0]const u8 = &.{},
    param_types: ?[]type = null,
    func_type: type,
    func: *const fn()void,
};

pub fn Reducer(data: anytype) SpecReducer {
    return .{
        .name = data.name,
        .lifecycle = if(@hasField(@TypeOf(data), "lifecycle")) data.lifecycle else .None,
        .params = if(@hasField(@TypeOf(data), "params")) data.params else &.{},
        .func = @ptrCast(data.func),
        .func_type = @TypeOf(data.func.*)
    };
}

pub const Index = struct {
    name: []const u8,
    layout: std.meta.Tag(RawIndexAlgorithm),
};

pub const TableAttribs = struct {
    type: TableType = .User,
    access: TableAccess = .Private,
    primary_key: ?[]const u8 = null,
    schedule: ?[]const u8 = null,
    indexes: ?[]const Index = null,
    unique: ?[]const []const u8 = null,
    autoinc: ?[]const [:0]const u8 = null,
};

pub const Table = struct {
    name: []const u8,
    schema: type,
    attribs: TableAttribs = .{},
};

pub const Spec = struct {
    tables: []const Table,
    reducers: []const SpecReducer,
    row_level_security: []const []const u8,
    includes: []const Spec = &.{},
};

pub fn SpecBuilder(comptime spec: Spec) RawModuleDefV9 {
    comptime {
        //var moduleDef: RawModuleDefV9 = undefined;
        var tableDefs: []const RawTableDefV9 = &[_]RawTableDefV9{};
        var reducerDefs: []const RawReducerDefV9 = &[_]RawReducerDefV9{};

        var raw_types: []const AlgebraicType = &[_]AlgebraicType{};
        var types: []const RawTypeDefV9 = &[_]RawTypeDefV9{};

        var row_level_security: []const RawRowLevelSecurityDefV9 = &[_]RawRowLevelSecurityDefV9{};

        var structDecls: []const StructImpl = &[_]StructImpl{};

        for(spec.tables) |table| {
            const table_name: []const u8 = table.name;
            const table_type: TableType = table.attribs.type;
            const table_access: TableAccess = table.attribs.access;
            const product_type_ref: AlgebraicTypeRef = AlgebraicTypeRef{
                .inner = addStructImpl(&structDecls, table.schema),
            };
            const primary_key: []const u16 = blk: {
                if(table.attribs.primary_key) |key| {
                    const fieldIdx = std.meta.fieldIndex(table.schema, key);
                    if(fieldIdx == null) {
                        @compileLog(table.schema, key);
                        @compileError("Primary Key `" ++ table_name ++ "." ++ key ++ "` does not exist in table schema `"++@typeName(table.schema)++"`!");
                    }
                    break :blk &[_]u16{ fieldIdx.?, };
                }
                break :blk &[_]u16{};
            };

            var indexes: []const RawIndexDefV9 = &[_]RawIndexDefV9{};
            if(table.attribs.primary_key) |key| {
                indexes = indexes ++ &[_]RawIndexDefV9{
                    RawIndexDefV9{
                        .name = null,
                        .accessor_name = key,
                        .algorithm = .{
                            .BTree = &.{ 0 }
                        }
                    }
                };
            }
            if(table.attribs.indexes) |_indexes| {
                for(_indexes) |index| {

                    const fieldIndex = std.meta.fieldIndex(table.schema, index.name).?;

                    const indexAlgo: RawIndexAlgorithm = blk: {
                        switch(index.layout) {
                            .BTree => break :blk .{ .BTree = &.{ fieldIndex } },
                            .Hash => break :blk .{ .Hash = &.{ fieldIndex } },
                            .Direct => break :blk .{ .Direct = fieldIndex },
                        }
                    };

                    indexes = indexes ++ &[_]RawIndexDefV9{
                        RawIndexDefV9{
                            .name = null,
                            .accessor_name = index.name,
                            .algorithm = indexAlgo
                        }
                    };
                }
            }

            var constraints: []const RawConstraintDefV9 = &[_]RawConstraintDefV9{};
            if(table.attribs.primary_key) |_| {
                constraints = constraints ++ &[_]RawConstraintDefV9{
                    RawConstraintDefV9{
                        .name = null,
                        .data = .{ .unique = .{ .Columns = &.{ primary_key[0] } } },
                    }
                };
            }

            const schedule: ?RawScheduleDefV9 = schedule_blk: {
                if(table.attribs.schedule == null) break :schedule_blk null;
                const column = column_blk: for(std.meta.fields(table.schema), 0..) |field, i| {
                    if(field.type == ScheduleAt) break :column_blk i;
                };
                const resolvedReducer = blk: {
                    for(spec.reducers) |reducer| {
                        if(std.mem.eql(u8, reducer.name, table.attribs.schedule.?))
                            break :blk reducer;
                    }
                    @compileError("Reducer of name `"++table.attribs.schedule.?++"` does not exist!");
                };
                break :schedule_blk RawScheduleDefV9{
                    .name = table_name ++ "_sched",
                    .reducer_name = resolvedReducer.name,
                    .scheduled_at_column = column,
                };
            };

            var sequences: []const RawSequenceDefV9 = &[_]RawSequenceDefV9{};
            if(table.attribs.autoinc) |autoincs| {
                for(autoincs) |autoinc| {
                    sequences = sequences ++ &[_]RawSequenceDefV9{
                        RawSequenceDefV9{
                            .name =  table_name ++ "_" ++ autoinc ++ "_seq",
                            .column = std.meta.fieldIndex(table.schema, autoinc).?,
                            .start = null,
                            .min_value = null,
                            .max_value = null,
                            .increment = 1,
                        }
                    };
                }
            }

            tableDefs = tableDefs ++ &[1]RawTableDefV9{
                .{
                    .name = table_name,
                    .product_type_ref = product_type_ref,
                    .primary_key = primary_key,
                    .indexes = indexes,
                    .constraints = constraints,
                    .sequences = sequences,
                    .schedule = schedule,
                    .table_type = table_type,
                    .table_access = table_access,
                }
            };
        }

        @setEvalBranchQuota(structDecls.len * 100);
        for(structDecls) |structDecl| {
            var product_elements: []const ProductTypeElement = &[_]ProductTypeElement{};

            for(structDecl.fields) |field|
            {
                product_elements = product_elements ++ &[_]ProductTypeElement{
                    .{
                        .name = field.name,
                        .algebraic_type = field.type,
                    }
                };
            }

            raw_types = raw_types ++ &[_]AlgebraicType{
                .{
                    .Product = .{
                        .elements = product_elements,
                    }
                },
            };

            types = types ++ &[_]RawTypeDefV9{
                .{
                    .name = .{
                        .scope = &[_][]u8{},
                        .name = structDecl.name
                    },
                    .ty = .{ .inner = raw_types.len-1, },
                    .custom_ordering = true,
                }
            };
        }

        for(spec.reducers) |reducer| {
            const name: []const u8 = reducer.name;
            const lifecycle: Lifecycle = reducer.lifecycle;
            
            var params: []const ProductTypeElement = &[_]ProductTypeElement{};
            const param_names = reducer.params;

            for(@typeInfo(reducer.func_type).@"fn".params[1..], param_names) |param, param_name| {
                params = params ++ &[_]ProductTypeElement{
                    .{
                        .name = param_name,
                        .algebraic_type = getStructImplOrType(structDecls, param.type.?),
                    }
                };
            }

            reducerDefs = reducerDefs ++ &[_]RawReducerDefV9{
                .{
                    .name = name,
                    .params = .{ .elements = params },
                    .lifecycle = lifecycle,
                },
            };
        }

        for(spec.row_level_security) |rls| {
            row_level_security = row_level_security ++ &[_]RawRowLevelSecurityDefV9{
                RawRowLevelSecurityDefV9{
                    .sql = rls,
                }
            };
        }

        return .{
            .typespace = .{
                .types = raw_types,
            },
            .tables = tableDefs,
            .reducers = reducerDefs,
            .types = types,
            .misc_exports = &[_]RawMiscModuleExportV9{},
            .row_level_security = row_level_security,
        };
    }
}

pub const globalSpec: Spec = blk: {
    const root = @import("root");
    for(@typeInfo(root).@"struct".decls) |decl| {
        const field = @field(root, decl.name);
        if(@TypeOf(field) == Spec) {
            break :blk field;
        }
    }
    @compileError("No spacetime spec found in root file!");
}; 

pub export fn __describe_module__(description: BytesSink) void {
    const allocator = std.heap.wasm_allocator;
    std.log.debug("Hello from Zig!", .{});
    
    var moduleDefBytes = std.ArrayList(u8).init(allocator);
    defer moduleDefBytes.deinit();

    const compiledModule = comptime SpecBuilder(globalSpec);

    //PrintModule(compiledModule);

    serialize_module(&moduleDefBytes, compiledModule) catch {
       std.log.err("Allocator Error: Cannot continue!", .{});
       @panic("Allocator Error: Cannot continue!");
    };

    write_to_sink(description, moduleDefBytes.items) catch @panic("Failed to write Module Descripton to SpacetimeDB!");
}

pub export fn __call_reducer__(
    id: usize,
    sender_0: u64,
    sender_1: u64,
    sender_2: u64,
    sender_3: u64,
    conn_id_0: u64,
    conn_id_1: u64,
    timestamp: u64,
    args: BytesSource,
    err: BytesSink,
) i16 {
    _ = err;

    const backend_allocator = std.heap.wasm_allocator;
    var arena_allocator = std.heap.ArenaAllocator.init(backend_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();
    
    var ctx: ReducerContext = .{
        .allocator = allocator,
        .sender = std.mem.bytesAsValue(Identity, std.mem.sliceAsBytes(&[_]u64{ sender_0, sender_1, sender_2, sender_3})).*,
        .timestamp = Timestamp{ .__timestamp_micros_since_unix_epoch__ = @intCast(timestamp), },
        .connection_id  = std.mem.bytesAsValue(ConnectionId, std.mem.sliceAsBytes(&[_]u64{ conn_id_0, conn_id_1})).*,
        .db = .{
            .allocator = backend_allocator,
            .frame_allocator = allocator,
        },
    };

    const spec: Spec = blk: {
        const root = @import("root");
        inline for(@typeInfo(root).@"struct".decls) |decl| {
            const field = @field(root, decl.name);
            if(@TypeOf(field) == Spec) {
                break :blk field;
            }
        }
    };

    const reducers = spec.reducers;

    inline for(reducers, 0..) |reducer, i| {
        if(id == i) {
            const func = reducer.func_type;
            const params = @typeInfo(func).@"fn".params;
            const param_names = reducer.params;
            comptime var argCount = 1;
            comptime var argList: []const std.builtin.Type.StructField = &[_]std.builtin.Type.StructField{
                std.builtin.Type.StructField{
                    .alignment = @alignOf(*ReducerContext),
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .name = "0",
                    .type = *ReducerContext,
                }
            };

            inline for(params[1..], param_names) |param, name| {
                _ = name;
                argList = argList ++ &[_]std.builtin.Type.StructField{
                    std.builtin.Type.StructField{
                        .alignment = @alignOf(param.type.?),
                        .default_value_ptr = null,
                        .is_comptime = false,
                        .name = comptime utils.itoa(argCount),
                        .type = param.type.?,
                    }
                };
                argCount += 1;
            }

            const argsStruct = @Type(.{
                .@"struct" = std.builtin.Type.Struct{
                    .backing_integer = null,
                    .decls = &[_]std.builtin.Type.Declaration{},
                    .fields = argList,
                    .is_tuple = true,
                    .layout = .auto,
                }
            });

            var constructedArg: argsStruct = undefined;

            @field(constructedArg, "0") = &ctx;

            if(args.inner != 0) {
                inline for(params, 0..) |param, name| {
                    comptime if(name == 0) continue;
                    @field(constructedArg, utils.itoa(name)) = readArg(allocator, args, param.type.?) catch |err2| {
                        std.log.err("Error: {}", .{err2});
                        @panic("blah");
                    };
                }
            }

            callReducer(reducers, i, constructedArg) catch |errRet| {
                std.log.err("{s}", .{@errorName(errRet)});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
            };
        }
    }

    return 0;
}
