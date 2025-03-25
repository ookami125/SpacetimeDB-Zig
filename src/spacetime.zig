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

pub fn print(fmt: []const u8) void {
    console_log(2, null, 0, null, 0, 0, fmt.ptr, fmt.len);
}

pub fn debug_print(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    std.fmt.format(fbs.writer().any(), fmt, args) catch {
        return print("Expand the buf in debug_print!");
    };
    return print(fbs.getWritten());
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

pub const ScheduleAt = union(enum){
    Interval: struct{ __time_duration_micros__: i64 },
    Time: struct{ __timestamp_micros_since_unix_epoch__: i64 },
};

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
        .U32 => u32,
        .U64 => u64,
        .I32 => i32,
        .I64 => i64,
        else => unreachable,
    };
}

const StructFieldImpl = struct {
    name: []const u8,
    type: AlgebraicType,
};

pub fn readArg(allocator: std.mem.Allocator, args: BytesSource, comptime t: AlgebraicType) !spacetimeType2ZigType(t) {
    switch(t) {
        .String => {
            var maxbuf: [4]u8 = undefined;
            const len_buf = try read_bytes_source(args, &maxbuf);
            const len: usize = std.mem.bytesToValue(u32, len_buf);
            const string_buf = try allocator.alloc(u8, len);
            return try read_bytes_source(args, string_buf);
        },
        .U32, .U64, .I32, .I64 => {
            const read_type = spacetimeType2ZigType(t);
            var maxbuf: [@sizeOf(read_type)]u8 = undefined;
            const len_buf = try read_bytes_source(args, &maxbuf);
            const len: read_type = std.mem.bytesToValue(read_type, len_buf);
            return len;
        },
        else => @compileError("unsupported type in readArg!"),
    }
}

pub fn zigTypeToSpacetimeType(comptime param: ?type) AlgebraicType {
    if(param == null) @compileError("Null parameter type passed to zigParamsToSpacetimeParams");
    return switch(param.?) {
        []const u8 => .{ .String = {} },
        i32 => .{ .I32 = {}, },
        i64 => .{ .I64 = {}, },
        u32 => .{ .U32 = {}, },
        u64 => .{ .U64 = {}, },
        f32 => .{ .F32 = {}, },
        //Identity => .{ .U256 = {}, },
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

pub fn addStructImpl(structImpls: *[]const StructImpl, layout: anytype) u32 {
    const name = blk: {
        var temp: []const u8 = @typeName(layout);
        if(std.mem.lastIndexOf(u8, temp, ".")) |idx|
            temp = temp[idx+1..];
        break :blk temp;
    };

    //FIXME: Search for existing structImpl of provided layout. I think the current might work, but I don't trust it.
    inline for(structImpls.*, 0..) |structImpl, i| {
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

pub fn compile(comptime moduleTables : []const Table, comptime moduleReducers : []const Reducer) !RawModuleDefV9 {
    var def : RawModuleDefV9 = undefined;
    _ = &def;

    var tableDefs: []const RawTableDefV9 = &[_]RawTableDefV9{};
    var reducerDefs: []const RawReducerDefV9 = &[_]RawReducerDefV9{};

    var raw_types: []const AlgebraicType = &[_]AlgebraicType{};
    var types: []const RawTypeDefV9 = &[_]RawTypeDefV9{};

    var structDecls: []const StructImpl = &[_]StructImpl{};

    inline for(moduleTables) |table| {
        //const table: @as(*const field.type, @alignCast(@ptrCast(field.default_value))).* = .{};
        const name: []const u8 = table.name.?;
        const table_type: TableType = table.type;
        const table_access: TableAccess = table.access;
        const product_type_ref: AlgebraicTypeRef = AlgebraicTypeRef{
            .inner = addStructImpl(&structDecls, table.schema),
        };
        tableDefs = tableDefs ++ &[_]RawTableDefV9{
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

    inline for(structDecls) |structDecl| {
        var product_elements: []const ProductTypeElement = &[_]ProductTypeElement{};

        inline for(structDecl.fields) |field|
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

    inline for(moduleReducers) |reducer| {
        const name: []const u8 = reducer.name.?;
        const lifecycle: Lifecycle = reducer.lifecycle;
        
        var params: []const ProductTypeElement = &[_]ProductTypeElement{};
        const param_names = reducer.params;

        for(@typeInfo(reducer.func_type).@"fn".params[1..], param_names) |param, param_name| {
            params = params ++ &[_]ProductTypeElement{
                .{
                    .name = param_name,
                    .algebraic_type = zigTypeToSpacetimeType(param.type),
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

    return .{
        .typespace = .{
            .types = raw_types,
        },
        .tables = tableDefs,
        .reducers = reducerDefs,
        .types = types,
        .misc_exports = &[_]RawMiscModuleExportV9{},
        .row_level_security = &[_]RawRowLevelSecurityDefV9{},
    };
}

pub fn callReducer(comptime mdef: []const Reducer, id: usize, args: anytype) void {
    inline for(mdef, 0..) |field, i| {
        if(id == i) {
            const func = field.func_type;
            if(std.meta.fields(@TypeOf(args)).len == @typeInfo(func).@"fn".params.len) {
                const func_val: func = @as(*const func, @ptrCast(field.func)).*;
                return @call(.auto, func_val, args);
            }
        
            const name: []const u8 = field.name.?;
            var buf: [128]u8 = undefined;
            print(std.fmt.bufPrint(&buf, "invalid number of args passed to {s}, expected {} got {}", .{name, @typeInfo(func).@"fn".params.len, std.meta.fields(@TypeOf(args)).len}) catch "!!!Error while printing last error!!!");
            @panic("invalid number of args passed to func");
        }
    }
}

pub fn PrintModule(data: anytype) void {
    var buf: [64]u8 = undefined;
    print(std.fmt.bufPrint(&buf, "\"{s}\": {{", .{@typeName(@TypeOf(data))}) catch "<Error>");
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
        [][]const u8 => {
            for(data) |elem| {
                PrintModule(elem);
            }
        },
        []const u8 => {
            print(std.fmt.bufPrint(&buf, "\"{s}\"", .{data}) catch "<Error>");
        },
        u32 => {
            print(std.fmt.bufPrint(&buf, "{}", .{data}) catch "<Error>");
        },
        else => {
            print("\"...\"");
        },
    }
    print("},");
}

pub const Param = struct {
    name: []const u8,
};

pub const Reducer = struct {
    name: ?[]const u8 = null,
    lifecycle: Lifecycle = .None,
    params: []const [:0]const u8 = &.{},
    param_types: ?[]type = null,
    func_type: type,
    func: *const fn()void,
};

pub const Table = struct {
    name: ?[]const u8 = null,
    schema: type,
    type: TableType = .User,
    access: TableAccess = .Private,
};

pub const reducers: []const Reducer = blk: {
    var temp: []const Reducer = &.{};
    const root = @import("root");
    for(@typeInfo(root).@"struct".decls) |decl| {
        const field = @field(root, decl.name);
        if(@TypeOf(@field(root, decl.name)) == Reducer) {
            temp = temp ++ &[_]Reducer{ 
                Reducer{
                    .name = field.name orelse decl.name,
                    .lifecycle = field.lifecycle,
                    .params = field.params,
                    .func = field.func,
                    .func_type = field.func_type,
                }
            };
        }
    }
    break :blk temp;
};

pub const tables: []const Table = blk: {
    var temp: []const Table = &.{};
    const root = @import("root");
    for(@typeInfo(root).@"struct".decls) |decl| {
        const field = @field(root, decl.name);
        if(@TypeOf(@field(root, decl.name)) == Table) {
            temp = temp ++ &[_]Table{ 
                Table{
                    .type = field.type,
                    .access = field.access,
                    .schema = field.schema,
                    .name = field.name orelse decl.name,
                }
            };
        }
    }
    break :blk temp;
};

pub export fn __describe_module__(description: BytesSink) void {
    const allocator = std.heap.wasm_allocator;
    print("Hello from Zig!");
    
    var moduleDefBytes = std.ArrayList(u8).init(allocator);
    defer moduleDefBytes.deinit();

    const compiledModule = comptime compile(tables, reducers) catch |err| {
        var buf: [1024]u8 = undefined;
        const fmterr = std.fmt.bufPrint(&buf, "Error: {}", .{err}) catch {
            @compileError("ERROR2: No Space Left! Expand error buffer size!");
        };
        @compileError(fmterr);
    };

    serialize_module(&moduleDefBytes, compiledModule) catch {
       print("Allocator Error: Cannot continue!");
       @panic("Allocator Error: Cannot continue!");
    };

    write_to_sink(description, moduleDefBytes.items);
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

    inline for(reducers, 0..) |reducer, i| {
        if(id == i) {
            const func = reducer.func_type;
            const params = @typeInfo(func).@"fn".params;
            const param_names = reducer.params;
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
                    @field(constructedArg, utils.itoa(name)) = readArg(allocator, args, zigTypeToSpacetimeType(param.type.?)) catch |err2| {
                        var buf: [512]u8 = undefined;
                        print(std.fmt.bufPrint(&buf, "Error: {}", .{err2}) catch "Expand Error Buffer!");
                        @panic("blah");
                    };
                }
            }

            callReducer(reducers, i, constructedArg);
        }
    }

    return 0;
}
