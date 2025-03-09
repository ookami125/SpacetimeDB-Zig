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