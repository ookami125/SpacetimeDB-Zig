// Copyright 2025 Tyler Peterson, Licensed under MPL-2.0

const std = @import("std");

pub const types = @import("types.zig");

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

fn serialize_raw_table_def_v9(array: *std.ArrayList(u8), val: RawTableDefV9) !void {
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.name.len))));
    try array.appendSlice(val.name);
    try serialize_algebraic_type_ref(array, val.product_type_ref);
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.primary_key.len))));
    try array.appendSlice(std.mem.sliceAsBytes(val.primary_key));
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.indexes.len))));
    for(val.indexes) |index| {
        try serialize_raw_index_def_v9(array, index);
    }
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.constraints.len))));
    for(val.constraints) |constraint| {
        try serialize_raw_constraint_def_v9(array, constraint);
    }
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.sequences.len))));
    for(val.sequences) |sequence| {
        try serialize_raw_sequence_def_v9(array, sequence);
    }
    try array.appendSlice(&[_]u8{ @intFromBool(val.schedule == null) });
    if(val.schedule) |schedule| {
        try serialize_raw_schedule_def_v9(array, schedule);
    }
    try serialize_table_type(array, val.table_type);
    try serialize_table_access(array, val.table_access);
}

fn serialize_raw_reducer_def_v9(array: *std.ArrayList(u8), val: RawReducerDefV9) !void {
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.name.len))));
    try array.appendSlice(val.name);
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.params.elements.len))));
    for(val.params.elements) |element| {
        try serialize_product_type_element(array, element);
    }
    try array.appendSlice(&[_]u8{ @intFromBool(val.lifecycle == .None) });
    if(val.lifecycle != .None) {
        try serialize_lifecycle(array, val.lifecycle);
    }
}

fn serialize_lifecycle(array: *std.ArrayList(u8), val: Lifecycle) !void {
    try array.appendSlice(&[_]u8{@intFromEnum(val)});
}

fn serialize_algebraic_type_ref(array: *std.ArrayList(u8), val: AlgebraicTypeRef) !void {
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.inner))));
}

fn serialize_raw_type_def_v9(array: *std.ArrayList(u8), val: RawTypeDefV9) !void {
    try serialize_raw_scoped_type_name_v9(array, val.name);
    try serialize_algebraic_type_ref(array, val.ty);
    try serialize_bool(array, val.custom_ordering);
}

fn serialize_raw_scoped_type_name_v9(array: *std.ArrayList(u8), val: RawScopedTypeNameV9) !void {
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.scope.len))));
    for(val.scope) |sub_scope| {
        try serialize_raw_identifier(array, sub_scope);
    }
    try serialize_raw_identifier(array, val.name);
}

fn serialize_raw_identifier(array: *std.ArrayList(u8), val: RawIdentifier) !void {
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.len))));
    try array.appendSlice(val);
}

fn serialize_bool(array: *std.ArrayList(u8), val: bool) !void {
    try array.appendSlice(&[_]u8{@intFromBool(val)});
}

fn serialize_raw_misc_module_export_v9(array: *std.ArrayList(u8), val: RawMiscModuleExportV9) !void {
    _ = array;
    _ = val;
    unreachable;
}

fn serialize_raw_row_level_security_def_v9(array: *std.ArrayList(u8), val: RawRowLevelSecurityDefV9) !void {
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.sql.len))));
    try array.appendSlice(val.sql);
}

fn serialize_raw_index_algorithm(array: *std.ArrayList(u8), val: RawIndexAlgorithm) !void {
    try array.appendSlice(&[_]u8{@intFromEnum(val)});
    switch(val) {
        .BTree, .Hash => |deref| {
            try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(deref.len))));
            try array.appendSlice(std.mem.sliceAsBytes(deref.ptr[0..deref.len]));
        },
        .Direct => unreachable,
    }
}

fn serialize_raw_index_def_v9(array: *std.ArrayList(u8), val: RawIndexDefV9) !void {
    try array.appendSlice(&[_]u8{ @intFromBool(val.name == null) });
    if(val.name) |name| {
        try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(name.len))));
        try array.appendSlice(name);
    }
    try array.appendSlice(&[_]u8{ @intFromBool(val.accessor_name == null) });
    if(val.accessor_name) |accessor_name| {
        try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(accessor_name.len))));
        try array.appendSlice(accessor_name);
    }
    try serialize_raw_index_algorithm(array, val.algorithm);
}

fn serialize_raw_constraint_def_v9(array: *std.ArrayList(u8), val: RawConstraintDefV9) !void {
    try array.appendSlice(&[_]u8{ @intFromBool(val.name == null) });
    if(val.name) |name| {
        try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(name.len))));
        try array.appendSlice(name);
    }
    // I have no idea what union this applies to, could be data or unique
    // Both only have 1 option so right now it doesn't matter though.
    try array.appendSlice(&.{ 0 });
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.data.unique.Columns.len))));
    try array.appendSlice(std.mem.sliceAsBytes(val.data.unique.Columns.ptr[0..val.data.unique.Columns.len]));
}

fn serialize_raw_sequence_def_v9(array: *std.ArrayList(u8), val: RawSequenceDefV9) !void {
    try array.appendSlice(&[_]u8{ @intFromBool(val.name == null) });
    if(val.name) |name| {
        try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(name.len))));
        try array.appendSlice(name);
    }
    try array.appendSlice(&std.mem.toBytes(@as(u16, @intCast(val.column))));
    try array.appendSlice(&[_]u8{ @intFromBool(val.start == null) });
    try array.appendSlice(&[_]u8{ @intFromBool(val.min_value == null) });
    if(val.min_value != null) undefined;
    try array.appendSlice(&[_]u8{ @intFromBool(val.max_value == null) });
    if(val.max_value != null) undefined;
    try array.appendSlice(&std.mem.toBytes(@as(i128, @intCast(val.increment))));
}

fn serialize_raw_schedule_def_v9(array: *std.ArrayList(u8), val: RawScheduleDefV9) !void {
    try array.appendSlice(&[_]u8{ @intFromBool(val.name == null) });
    if(val.name) |name| {
        try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(name.len))));
        try array.appendSlice(name);
    }
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.reducer_name.len))));
    try array.appendSlice(val.reducer_name);

    try array.appendSlice(&std.mem.toBytes(@as(u16, @intCast(val.scheduled_at_column))));
}

fn serialize_table_type(array: *std.ArrayList(u8), val: TableType) !void {
    try array.appendSlice(&[_]u8{@intFromEnum(val)});
}

fn serialize_table_access(array: *std.ArrayList(u8), val: TableAccess) !void {
    try array.appendSlice(&[_]u8{@intFromEnum(val)});
}

fn serialize_sum_type_variant(array: *std.ArrayList(u8), val: SumTypeVariant) !void {
    try array.appendSlice(&[_]u8{ @intFromBool(val.name == null) });
    if(val.name) |name| {
        try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(name.len))));
        try array.appendSlice(name);
    }
    try serialize_algebraic_type(array, val.algebraic_type);
}

fn serialize_sum_type(array: *std.ArrayList(u8), val: SumType) std.mem.Allocator.Error!void {
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.variants.len))));
    for(val.variants) |variant| {
        try serialize_sum_type_variant(array, variant);
    }
}

fn serialize_product_type_element(array: *std.ArrayList(u8), val: ProductTypeElement) !void {
    try array.appendSlice(&[_]u8{ 0 });
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.name.len))));
    try array.appendSlice(val.name);
    try serialize_algebraic_type(array, val.algebraic_type);
}

fn serialize_product_type(array: *std.ArrayList(u8), val: ProductType) std.mem.Allocator.Error!void {
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.elements.len))));
    for(val.elements) |element| {
        try serialize_product_type_element(array, element);
    }
}

fn serialize_algebraic_type(array: *std.ArrayList(u8), val: AlgebraicType) !void {
    try array.appendSlice(&[_]u8{@intFromEnum(val)});
    switch(val) {
        AlgebraicType.Product => |product| {
            try serialize_product_type(array, product);
        },
        AlgebraicType.Ref => |ref| {
            try array.appendSlice(&std.mem.toBytes(ref.inner));
        },
        AlgebraicType.Sum => |sum| {
            try serialize_sum_type(array, sum);
        },
        else => {},
    }
}

fn serialize_typespace(array: *std.ArrayList(u8), val: Typespace) !void {
    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.types.len))));
    for(val.types) |_type| {
        try serialize_algebraic_type(array, _type);
    }
}

pub fn serialize_module(array: *std.ArrayList(u8), val: RawModuleDefV9) !void {
    try array.appendSlice(&[_]u8{1});
    
    try serialize_typespace(array, val.typespace);

    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.tables.len))));
    for(val.tables) |table| {
        try serialize_raw_table_def_v9(array, table);
    }

    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.reducers.len))));
    for(val.reducers) |reducer| {
        try serialize_raw_reducer_def_v9(array, reducer);
    }

    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.types.len))));
    for(val.types) |_type| {
        try serialize_raw_type_def_v9(array, _type);
    }

    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.misc_exports.len))));
    for(val.misc_exports) |misc_export| {
        try serialize_raw_misc_module_export_v9(array, misc_export);
    }

    try array.appendSlice(&std.mem.toBytes(@as(u32, @intCast(val.row_level_security.len))));
    for(val.row_level_security) |rls| {
        try serialize_raw_row_level_security_def_v9(array, rls);
    }
}
