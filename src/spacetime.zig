const std = @import("std");

pub const types = @import("spacetime/types.zig");
pub const serializer = @import("spacetime/serializer.zig");

pub const SumTypeVariant = types.SumTypeVariant;
pub const SumType = types.SumType;
pub const ArrayType = types.ArrayType;
pub const AlgebraicType = types.AlgebraicType;
pub const Typespace = types.Typespace;
pub const RawIdentifier = types.RawIdentifier;
pub const AlgebraicTypeRef = types.AlgebraicTypeRef;
pub const RawIndexAlgorithm = types.RawIndexAlgorithm;
pub const RawIndexDefV9 = types.RawIndexDefV9;
pub const RawUniqueConstraintDataV9 = types.RawUniqueConstraintDataV9;
pub const RawConstraintDataV9 = types.RawConstraintDataV9;
pub const RawConstraintDefV9 = types.RawConstraintDefV9;
pub const RawSequenceDefV9 = types.RawSequenceDefV9;
pub const RawScheduleDefV9 = types.RawScheduleDefV9;
pub const TableType = types.TableType;
pub const TableAccess = types.TableAccess;
pub const RawTableDefV9 = types.RawTableDefV9;
pub const ProductTypeElement = types.ProductTypeElement;
pub const ProductType = types.ProductType;
pub const Lifecycle = types.Lifecycle;
pub const ReducerContext = types.ReducerContext;
pub const ReducerFn = types.ReducerFn;
pub const RawReducerDefV9 = types.RawReducerDefV9;
pub const RawScopedTypeNameV9 = types.RawScopedTypeNameV9;
pub const RawTypeDefV9 = types.RawTypeDefV9;
pub const RawMiscModuleExportV9 = types.RawMiscModuleExportV9;
pub const RawSql = types.RawSql;
pub const RawRowLevelSecurityDefV9 = types.RawRowLevelSecurityDefV9;
pub const RawModuleDefV9 = types.RawModuleDefV9;

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

pub const BytesSink = extern struct { inner: u32 };
pub const BytesSource = extern struct { inner: u32 };

pub extern "spacetime_10.0" fn bytes_sink_write(sink: BytesSink, buffer_ptr: [*c]const u8, buffer_len_ptr: *usize) u16;

const NO_SUCH_BYTES = 8;
const NO_SPACE = 9;

pub fn write_to_sink(sink: BytesSink, _buf: []const u8) void {
    var buf: []const u8 = _buf;
    while(true) {
        const len: *usize = &buf.len;
        switch(bytes_sink_write(sink, buf.ptr, len)) {
            0 => {
                // Set `buf` to remainder and bail if it's empty.
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

pub fn parse_reducers(root: type) []const RawReducerDefV9 {
    const decls = std.meta.declarations(root);
    //@compileLog(.{ decls });

    var reducers : []const RawReducerDefV9 = &[_]RawReducerDefV9{};
    _ = &reducers;

    inline for(decls) |decl| {

        const temp = @field(root, decl.name);
        const temp_type = @typeInfo(@TypeOf(temp)); 
        if(temp_type != .@"fn") continue;
        if(temp_type.@"fn".params[0].type.? != *ReducerContext) continue;

        const lifecycle: ?Lifecycle = blk: {
            if(std.mem.eql(u8, decl.name, "Init")) break :blk .Init;
            if(std.mem.eql(u8, decl.name, "OnConnect")) break :blk .OnConnect;
            if(std.mem.eql(u8, decl.name, "OnDisconnect")) break :blk .OnDisconnect;
            break :blk null;
        };

        reducers = reducers ++ &[_]RawReducerDefV9{
            .{
                .name = decl.name,
                .params = .{ .elements = &[_]ProductTypeElement{} },
                .lifecycle = lifecycle,
            },
        };

    }

    return reducers;
}

pub fn Reducer(comptime func: anytype) type {
    const @"spacetime_10.0__reducer_" = struct {
        name: ?[]const u8 = null,
        func: @TypeOf(func) = func,
        lifecycle: ?Lifecycle = null,
    };
    return @"spacetime_10.0__reducer_";
}

pub fn Table(comptime table: anytype) type {
    _ = table;
    const @"spacetime_10.0__table_" = struct {
        name: ?[]const u8 = null,
        table_type: TableType = .User,
        table_access: TableAccess = .Private,
    };
    return @"spacetime_10.0__table_";
}

pub fn compile(comptime module : anytype) RawModuleDefV9 {
    var def : RawModuleDefV9 = undefined;
    _ = &def;

    //def.reducers = def.reducers ++ &[_]RawReducerDefV9{};
    var tables: []const RawTableDefV9 = &[_]RawTableDefV9{};
    var reducers: []const RawReducerDefV9 = &[_]RawReducerDefV9{};

    inline for(std.meta.fields(@TypeOf(module))) |field| {
        const name: []const u8 = @as(*const field.type, @alignCast(@ptrCast(field.default_value.?))).*.name orelse field.name;
        if( std.mem.endsWith(u8, @typeName(field.type), "spacetime_10.0__table_")) {
            const table_type: TableType = @as(*const field.type, @alignCast(@ptrCast(field.default_value.?))).*.table_type;
            const table_access: TableAccess = @as(*const field.type, @alignCast(@ptrCast(field.default_value.?))).*.table_access;
            tables = tables ++ &[_]RawTableDefV9{
                .{
                    .name = name,
                    .product_type_ref = .{ .inner = 0, },
                    .primary_key = &[_]u16{},
                    .indexes = &[_]RawIndexDefV9{},
                    .constraints = &[_]RawConstraintDefV9{},
                    .sequences = &[_]RawSequenceDefV9{},
                    .schedule = null,
                    .table_type = table_type,
                    .table_access = table_access,
                }
            };
            continue;
        }
        if( std.mem.endsWith(u8, @typeName(field.type), "spacetime_10.0__reducer_")) {
            const lifecycle: ?Lifecycle = @as(*const field.type, @alignCast(@ptrCast(field.default_value.?))).*.lifecycle;
            reducers = reducers ++ &[_]RawReducerDefV9{
                .{
                    .name = name,
                    .params = .{ .elements = &[_]ProductTypeElement{} },
                    .lifecycle = lifecycle,
                },
            };
            continue;
        }
        @compileLog(.{ field });
    }

    return .{
        .typespace = .{
            .types = &[_]AlgebraicType{
                .{
                    .Product = .{
                        .elements = &[_]ProductTypeElement{
                            .{
                                .name = "name",
                                .algebraic_type = .String,
                            }
                        }
                    }
                },
            },
        },
        .tables = tables,
        .reducers = reducers,
        .types = &[_]RawTypeDefV9{
            .{
                .name = .{
                    .scope = &[_][]u8{},
                    .name = "Person"
                },
                .ty = .{ .inner = 0, },
                .custom_ordering = true,
            }
        },
        .misc_exports = &[_]RawMiscModuleExportV9{},
        .row_level_security = &[_]RawRowLevelSecurityDefV9{},
    };
}