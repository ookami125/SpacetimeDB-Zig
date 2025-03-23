const std = @import("std");

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

pub fn print(fmt: []const u8) void {
    console_log(2, null, 0, null, 0, 0, fmt.ptr, fmt.len);
}

pub const BytesSink = extern struct { inner: u32 };
pub const BytesSource = extern struct { inner: u32 };

pub extern "spacetime_10.0" fn bytes_sink_write(sink: BytesSink, buffer_ptr: [*c]const u8, buffer_len_ptr: *usize) u16;
pub extern "spacetime_10.0" fn bytes_source_read(source: BytesSource, buffer_ptr: [*c]u8, buffer_len_ptr: *usize) i16;

pub const TableId = extern struct { _inner: u32, };
pub extern "spacetime_10.0" fn table_id_from_name(name: [*c]const u8, name_len: usize, out: *TableId) u16;
pub extern "spacetime_10.0" fn datastore_insert_bsatn(table_id: TableId, row_ptr: [*c]const u8, row_len_ptr: *usize) u16;

pub const RowIter = extern struct { _inner: u32, pub const INVALID = RowIter{ ._inner = 0}; };
pub extern "spacetime_10.0" fn row_iter_bsatn_advance(iter: RowIter, buffer_ptr: [*c]u8, buffer_len_ptr: *usize) i16;
pub extern "spacetime_10.0" fn datastore_table_scan_bsatn(table_id: TableId, out: [*c]RowIter) u16;

pub const EXHAUSTED = -1;
pub const OK = 0;
pub const NO_SUCH_ITER = 6;
pub const NO_SUCH_BYTES = 8;
pub const NO_SPACE = 9;
pub const BUFFER_TOO_SMALL = 11;

pub fn read_bytes_source(source: BytesSource, buf: []u8) ![]u8 {
    const INVALID: i16 = NO_SUCH_BYTES;

    var buf_len = buf.len;
    const ret = bytes_source_read(source, @ptrCast(buf), &buf_len);
    switch(ret) {
        -1, 0 => {},
        INVALID => return error.InvalidSource,
        else => unreachable,
    }

    return buf[0..buf_len];
}

pub fn write_to_sink(sink: BytesSink, _buf: []const u8) void {
    var buf: []const u8 = _buf;
    while(true) {
        const len: *usize = &buf.len;
        switch(bytes_sink_write(sink, buf.ptr, len)) {
            0 => {
                buf = buf[len.*..];
                if(buf.len == 0) {
                    break;
                }
            },
            NO_SUCH_BYTES => @panic("invalid sink passed"),
            NO_SPACE => @panic("no space left at sink"),
            else => unreachable,
        }
    }
}

pub const Param = struct {
    name: []const u8,
};

pub fn Reducer(comptime func: anytype) type {
    const @"spacetime_10.0__reducer_" = struct {
        name: ?[]const u8 = null,
        func: @TypeOf(func) = func,
        lifecycle: ?Lifecycle = null,
        param_names: []const [:0]const u8 = &[_][:0]const u8{},
    };

    return @"spacetime_10.0__reducer_";
}

pub const StructFieldDecl = struct {
    name: [:0]const u8,
    type: AlgebraicType,
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
        .U32 => u32,
        .U64 => u64,
        else => unreachable,
    };
}

pub fn Struct(comptime decl: StructDecl) type {
    const @"spacetime_10.0__table_" = struct {
        name: ?[]const u8 = decl.name,
        table_type: TableType = .User,
        table_access: TableAccess = .Private,
    };

    var zigStructMembers: []const std.builtin.Type.StructField = &[_]std.builtin.Type.StructField{
        std.builtin.Type.StructField{
            .name = "spacetime_10.0__table_",
            .type = @"spacetime_10.0__table_",
            .default_value = @as(?*const anyopaque, &@"spacetime_10.0__table_"{}),
            .is_comptime = false,
            .alignment = 0,
        },
    };

    inline for(decl.fields) |field| {
        zigStructMembers = zigStructMembers ++ &[_]std.builtin.Type.StructField{
            std.builtin.Type.StructField{
                .name = field.name,
                .type = spacetimeType2ZigType(field.type),
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            },
        };
    }

    return @Type(.{
        .@"struct" = std.builtin.Type.Struct{
            .decls = &[_]std.builtin.Type.Declaration{},
            .fields = zigStructMembers,
            .is_tuple = false,
            .layout = .@"auto",
        },
    });
}

pub fn readArg(allocator: std.mem.Allocator, args: BytesSource, comptime t: AlgebraicType) !spacetimeType2ZigType(t) {
    switch(t) {
        .String => {
            var maxbuf: [4]u8 = undefined;
            const len_buf = try read_bytes_source(args, &maxbuf);
            const len: usize = std.mem.bytesToValue(u32, len_buf);
            const string_buf = try allocator.alloc(u8, len);
            return try read_bytes_source(args, string_buf);
        },
        .U32 => {
            var maxbuf: [4]u8 = undefined;
            const len_buf = try read_bytes_source(args, &maxbuf);
            const len: u32 = std.mem.bytesToValue(u32, len_buf);
            return len;
        },
        .U64 => {
            var maxbuf: [8]u8 = undefined;
            const len_buf = try read_bytes_source(args, &maxbuf);
            const len: u64 = std.mem.bytesToValue(u64, len_buf);
            return len;
        },
        else => @compileError("unsupported type in readArg!"),
    }
}

pub fn zigTypeToSpacetimeType(comptime param: ?type) AlgebraicType {
    if(param == null) @compileError("Null parameter type passed to zigParamsToSpacetimeParams");
    return switch(param.?) {
        []const u8 => .{ .String = {} },
        u32 => .{ .U32 = {}, },
        u64 => .{ .U64 = {}, },
        else => {
            @compileLog(param.?);
            @compileError("Unmatched type passed to zigTypeToSpacetimeType!");
        },
    };
}

pub fn compile(comptime moduleTables : anytype, comptime moduleReducers : anytype) !RawModuleDefV9 {
    var def : RawModuleDefV9 = undefined;
    _ = &def;

    var tables: []const RawTableDefV9 = &[_]RawTableDefV9{};
    var reducers: []const RawReducerDefV9 = &[_]RawReducerDefV9{};

    var raw_types: []const AlgebraicType = &[_]AlgebraicType{};
    var types: []const RawTypeDefV9 = &[_]RawTypeDefV9{};

    inline for(std.meta.fields(@TypeOf(moduleTables))) |field| {
        const default_values = @as(*const field.type, @alignCast(@ptrCast(field.default_value.?))).*;
        const structInfo = blk: {
            for(@typeInfo(default_values).@"struct".fields) |structInfoField| {
                if(std.mem.eql(u8, structInfoField.name, "spacetime_10.0__table_")) {
                    break :blk structInfoField.type{};
                }
            }
        };

        var product_type_ref: AlgebraicTypeRef = undefined;
        {
            var product_elements: []const ProductTypeElement = &[_]ProductTypeElement{};
            
            inline for(@typeInfo(default_values).@"struct".fields, 0..) |table_field, i| {
                if(i == 0) continue;
                product_elements = product_elements ++ &[_]ProductTypeElement{
                    .{
                        .name = table_field.name,
                        .algebraic_type = zigTypeToSpacetimeType(table_field.type)
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
                        .name = field.name
                    },
                    .ty = .{ .inner = raw_types.len-1, },
                    .custom_ordering = true,
                }
            };

            product_type_ref.inner = types.len-1;
        }

        const name: []const u8 = structInfo.name.?;
        const table_type: TableType = structInfo.table_type;
        const table_access: TableAccess = structInfo.table_access;
        tables = tables ++ &[_]RawTableDefV9{
            .{
                .name = name,
                .product_type_ref = product_type_ref,
                .primary_key = &[_]u16{},
                .indexes = &[_]RawIndexDefV9{},
                .constraints = &[_]RawConstraintDefV9{},
                .sequences = &[_]RawSequenceDefV9{},
                .schedule = null,
                .table_type = table_type,
                .table_access = table_access,
            }
        };
    }

    inline for(std.meta.fields(@TypeOf(moduleReducers))) |field| {
        const default_values = @as(*const field.type, @alignCast(@ptrCast(field.default_value.?))).*;
        const name: []const u8 = default_values.name orelse field.name;
        if( std.mem.endsWith(u8, @typeName(field.type), "spacetime_10.0__reducer_")) {
            const lifecycle: ?Lifecycle = default_values.lifecycle;
            
            var params: []const ProductTypeElement = &[_]ProductTypeElement{};
            const param_names = default_values.param_names;

            for(@typeInfo(@TypeOf(default_values.func)).@"fn".params[1..], param_names) |param, param_name| {
                params = params ++ &[_]ProductTypeElement{
                    .{
                        .name = param_name,
                        .algebraic_type = zigTypeToSpacetimeType(param.type),
                    }
                };
            }

            reducers = reducers ++ &[_]RawReducerDefV9{
                .{
                    .name = name,
                    .params = .{ .elements = params },
                    .lifecycle = lifecycle,
                },
            };
            continue;
        }
        @compileLog(.{ field });
    }

    return .{
        .typespace = .{
            .types = raw_types,
        },
        .tables = tables,
        .reducers = reducers,
        .types = types,
        .misc_exports = &[_]RawMiscModuleExportV9{},
        .row_level_security = &[_]RawRowLevelSecurityDefV9{},
    };
}

pub fn callReducer(comptime mdef: anytype, id: usize, args: anytype) void {
    comptime var i = 0;
    inline for(std.meta.fields(@TypeOf(mdef))) |field| {
        if( comptime std.mem.endsWith(u8, @typeName(field.type), "spacetime_10.0__reducer_")) {
            if(id == i) {
                const func = @as(*const field.type, @alignCast(@ptrCast(field.default_value.?))).*.func;
                if(std.meta.fields(@TypeOf(args)).len == @typeInfo(@TypeOf(func)).@"fn".params.len) {
                    return @call(.auto, func, args);
                }
            
                const name: []const u8 = @as(*const field.type, @alignCast(@ptrCast(field.default_value.?))).*.name orelse field.name;
                var buf: [128]u8 = undefined;
                print(std.fmt.bufPrint(&buf, "invalid number of args passed to {s}, expected {} got {}", .{name, @typeInfo(@TypeOf(func)).@"fn".params.len, std.meta.fields(@TypeOf(args)).len}) catch "!!!Error while printing last error!!!");
                @panic("invalid number of args passed to func");
            }
            i += 1;
        }
    }
}

const moduleTablesDef = @import("root").moduleTablesDef;
const moduleReducersDef = @import("root").moduleReducersDef;

pub export fn __describe_module__(description: BytesSink) void {
    const allocator = std.heap.wasm_allocator;
    print("Hello from Zig!");
    
    var moduleDefBytes = std.ArrayList(u8).init(allocator);
    defer moduleDefBytes.deinit();

    serialize_module(&moduleDefBytes, comptime compile(moduleTablesDef, moduleReducersDef) catch |err| {
        var buf: [1024]u8 = undefined;
        const fmterr = std.fmt.bufPrint(&buf, "Error: {}", .{err}) catch {
            @compileError("ERROR2: No Space Left! Expand error buffer size!");
        };
        @compileError(fmterr);
    }) catch {
        print("Allocator Error: Cannot continue!");
        @panic("Allocator Error: Cannot continue!");
    };

    write_to_sink(description, moduleDefBytes.items);
}

fn itoa(comptime value: anytype) [:0]const u8 {
    comptime var s: []const u8 = &[_]u8{};
    comptime var n = value;
    if (n == 0) {
        s = s ++ .{'0'};
    } else {
        comptime while (n != 0) {
            s = s ++ .{'0' + (n % 10)};
            n = n / 10;
        };
    }
    return @ptrCast(s ++ .{0});
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

    const allocator = std.heap.wasm_allocator;
    
    var ctx: ReducerContext = .{
        .indentity = std.mem.bytesAsValue(u256, std.mem.sliceAsBytes(&[_]u64{ sender_0, sender_1, sender_2, sender_3})).*,
        .timestamp = timestamp,
        .connection_id  = std.mem.bytesAsValue(u128, std.mem.sliceAsBytes(&[_]u64{ conn_id_0, conn_id_1})).*,
        .db = .{
            .allocator = allocator,
        },
    };

    var i: usize = 0;
    inline for(std.meta.fields(@TypeOf(moduleReducersDef))) |field| {
        if( comptime std.mem.endsWith(u8, @typeName(field.type), "spacetime_10.0__reducer_")) {
            defer i += 1;
            if(id == i) {
                const func = std.meta.fields(field.type)[std.meta.fieldIndex(field.type, "func").?].type;
                const params = @typeInfo(func).@"fn".params;
                const param_names = @field(moduleReducersDef, field.name).param_names;
                comptime var argCount = 1;
                comptime var argList: []const std.builtin.Type.StructField = &[_]std.builtin.Type.StructField{
                    std.builtin.Type.StructField{
                        .alignment = 0,
                        .default_value = null,
                        .is_comptime = false,
                        .name = "0",
                        .type = *ReducerContext,
                    }
                };

                inline for(params[1..], param_names) |param, name| {
                    _ = name;
                    argList = argList ++ &[_]std.builtin.Type.StructField{
                        std.builtin.Type.StructField{
                            .alignment = 0,
                            .default_value = null,
                            .is_comptime = false,
                            .name = comptime itoa(argCount),
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
                        @field(constructedArg, itoa(name)) = readArg(allocator, args, zigTypeToSpacetimeType(param.type.?)) catch |err2| {
                            var buf: [512]u8 = undefined;
                            print(std.fmt.bufPrint(&buf, "Error: {}", .{err2}) catch "Expand Error Buffer!");
                            @panic("blah");
                        };
                    }
                }

                callReducer(moduleReducersDef, i, constructedArg);
            }
        }
    }

    return 0;
}
