const std = @import("std");

//extern "spacetime_10.0"
pub fn console_log(
    level: u8,
    target_ptr: [*c]const u8,
    target_len: usize,
    filename_ptr: [*c]const u8,
    filename_len: usize,
    line_number: u32,
    message_ptr: [*c]const u8,
    message_len: usize,
) void {
    _ = level;
    _ = target_ptr;
    _ = target_len;
    _ = filename_ptr;
    _ = filename_len;
    _ = line_number;
    _ = message_ptr;
    _ = message_len;
}

const BytesSink = extern struct { inner: u32 };
const BytesSource = extern struct { inner: u32 };

//extern "spacetime_10.0"
pub fn bytes_sink_write(sink: BytesSink, buffer_ptr: [*c]const u8, buffer_len_ptr: *usize) u16 {
    _ = sink;
    _ = buffer_ptr;
    _ = buffer_len_ptr;
    return 0;
}

const NO_SUCH_BYTES = 8;
const NO_SPACE = 9;

fn write_to_sink(sink: BytesSink, _buf: []const u8) void {
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

//pub const ReducerFn = fn(ReducerContext, []u8) ReducerResult;

pub const SumTypeVariant = struct {
    name: ?*[]u8,
    algebraic_type: AlgebraicType,
};

pub const SumType = struct {
    variants: []SumTypeVariant,
};

pub const ArrayType = struct {
    /// The base type every element of the array has.
    elem_ty: []AlgebraicType,
};

pub const AlgebraicType = union(enum) {
    Ref: AlgebraicTypeRef,
    Sum: SumType,
    Product: ProductType,
    Array: ArrayType,
    String: []u8,
    Bool: bool,
    I8: i8,
    U8: u8,
    I16: i16,
    U16: u16,
    I32: i32,
    U32: u32,
    I64: i64,
    U64: u64,
    I128: i128,
    U128: u128,
    I256: i256,
    U256: u256,
    F32: f32,
    F64: f64,
};

pub const Typespace = struct {
    types: []AlgebraicType,
};

pub const RawIdentifier = *[*c]u8;

pub const AlgebraicTypeRef = struct {
    inner: u32,
};

pub const RawIndexAlgorithm = union {
    BTree: []u16,
    Hash: []u16,
    Direct: u16,
};

pub const RawIndexDefV9 = struct {
    name: ?[]u8,
    accessor_name: ?[]u8,
    algorithm: RawIndexAlgorithm,
};

pub const RawUniqueConstraintDataV9 = union {
    Columns: u16,
};

pub const RawConstraintDataV9 = union {
    unique: RawUniqueConstraintDataV9,
};

pub const RawConstraintDefV9 = struct {
    name: ?[]u8,
    data: RawConstraintDataV9
};

pub const RawSequenceDefV9 = struct {
    Name: ?[]u8,
    Column: u16,
    Start: ?i128,
    MinValue: ?i128,
    MaxValue: ?i128,
    Increment: i128
};

pub const RawScheduleDefV9 = struct {
    Name: ?[]u8,
    ReducerName: []u8,
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
    primary_key: []u16,
    indexes: []RawIndexDefV9,
    constraints: []RawConstraintDefV9,
    sequences: []RawSequenceDefV9,
    schedule: ?RawScheduleDefV9,
    table_type: TableType,
    table_access: TableAccess,
};

pub const ProductTypeElement = struct {
    name: ?*[]u8,
    algebraic_type: AlgebraicType,
};

pub const ProductType = struct {
    elements: []ProductTypeElement,
};

pub const Lifecycle = enum {
    Init,
    OnConnect,
    OnDisconnect,
};

pub const RawReducerDefV9 = struct{
    name: RawIdentifier,
    params: ProductType,
    lifecycle: ?Lifecycle,
};

pub const RawScopedTypeNameV9 = struct {
    scope: [][]u8,
    name: []u8,
};

pub const RawTypeDefV9 = struct {
    name: RawScopedTypeNameV9,
    ty: AlgebraicTypeRef,
    custom_ordering: bool,
};

pub const RawMiscModuleExportV9 = enum {};

pub const RawSql = *[*c]u8;

pub const RawRowLevelSecurityDefV9 = struct {
    sql: RawSql,
};

pub const RawModuleDefV9 = struct {
    typespace: Typespace,
    tables: []RawTableDefV9,
    reducers: []RawReducerDefV9,
    types: []RawTypeDefV9,
    misc_exports: []RawMiscModuleExportV9,
    row_level_security: []RawRowLevelSecurityDefV9,
};

// V9(
//     RawModuleDefV9 {
//         typespace: Typespace [
//             Product(
//                 ProductType {
//                     "name": String,
//                 },
//             ),
//         ],
//         tables: [
//             RawTableDefV9 {
//                 name: "person",
//                 product_type_ref: AlgebraicTypeRef(
//                     0,
//                 ),
//                 primary_key: [],
//                 indexes: [],
//                 constraints: [],
//                 sequences: [],
//                 schedule: None,
//                 table_type: User,
//                 table_access: Private,
//             },
//         ],
//         reducers: [
//             RawReducerDefV9 {
//                 name: "add",
//                 params: ProductType {
//                     "name": String,
//                 },
//                 lifecycle: None,
//             },
//             RawReducerDefV9 {
//                 name: "identity_connected",
//                 params: ProductType {},
//                 lifecycle: Some(
//                     OnConnect,
//                 ),
//             },
//             RawReducerDefV9 {
//                 name: "identity_disconnected",
//                 params: ProductType {},
//                 lifecycle: Some(
//                     OnDisconnect,
//                 ),
//             },
//             RawReducerDefV9 {
//                 name: "init",
//                 params: ProductType {},
//                 lifecycle: Some(
//                     Init,
//                 ),
//             },
//             RawReducerDefV9 {
//                 name: "say_hello",
//                 params: ProductType {},
//                 lifecycle: None,
//             },
//         ],
//         types: [
//             RawTypeDefV9 {
//                 name: "Person",
//                 ty: AlgebraicTypeRef(
//                     0,
//                 ),
//                 custom_ordering: true,
//             },
//         ],
//         misc_exports: [],
//         row_level_security: [],
//     },
// )

const bytes = [_]u8{
    1, //VP9 
    1, 0, 0, 0, //Typespace.types.len
    2, //Typespace.types[0].tag(Product)
    1, 0, 0, 0, //Typespace.types[0].tag(Product).elements.len
    0, // optional?
    4, 0, 0, 0, //Typespace.types[0].tag(Product).elements[0].name.len
    110, 97, 109, 101,  //Typespace.types[0].tag(Product).elements[0].name[0..4] "name"
    4, //Typespace.types[0].tag(Product).elements[0].algebraic_type(String)
    1, 0, 0, 0, //Typespace.types[0].tag(Product).elements[0].algebraic_type(String).len
    
    6, 0, 0, 0, //tables[0].name.len
    112, 101, 114, 115, 111, 110, //tables[0].name "person"
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    1,
    1,
    1,
    5, 0, 0, 0,
    
    3, 0, 0, 0,
    97, 100, 100, 
    
    1, 0, 0, 0,
    0,
    
    4, 0, 0, 0,
    110, 97, 109, 101,
    4,
    1,
    18, 0, 0, 0,
    105, 100, 101, 110, 116, 105, 116, 121, 95, 99, 111, 110, 110, 101, 99, 116, 101, 100, 
    
    0, 0, 0, 0,
    0,
    1,
    21, 0, 0, 0,
    105, 100, 101, 110, 116, 105, 116, 121, 95, 100, 105, 115, 99, 111, 110, 110, 101, 99, 116, 101, 100,
    
    0, 0, 0, 0,
    0,
    2,
    4, 0, 0, 0,
    105, 110, 105, 116,
    0, 0, 0, 0,
    0,
    0,
    9, 0, 0, 0,
    115, 97, 121, 95, 104, 101, 108, 108, 111,
    0, 0, 0, 0,
    1,
    1,
    0, 0, 0, 0,
    
    0, 0, 0,
    
    6, 0, 0, 0, 
    80, 101, 114, 115, 111, 110,
    
    0, 0, 0, 0,
    1, 0, 0, 0,
    0, 0, 0, 0, 
    0
};

pub fn print(comptime fmt: []const u8) void {
    console_log(0, null, 0, null, 0, 0, fmt.ptr, fmt.len);
}

pub fn module_write(val: anytype) void {
    switch(@TypeOf(val)) {
        RawModuleDefV9 => {
            std.debug.print("{{ 1 }},\n", .{});
            module_write(val.typespace);
        },
        Typespace => {
            std.debug.print("{any},\n", .{std.mem.toBytes(@as(u32, @intCast(val.types.len)))});
            for(val.types) |_type| {
                module_write(_type);
            }
        },
        AlgebraicType => {
            switch(val) {
                AlgebraicType.String => |string| {
                    std.debug.print("{any},\n", .{string});
                },
                AlgebraicType.Product => |product| {
                    module_write(product);
                },
                else => std.debug.print("{any},\n", .{val}),
            }
        },
        ProductType => {
            std.debug.print("{any},\n", .{std.mem.toBytes(@as(u32, @intCast(val.elements.len)))});
            for(val.elements) |element| {
                module_write(element);
            }

        },
        ProductTypeElement => {
            if(val.name == null) {
                std.debug.print("{{ 1 }},\n", .{});
            } else {
                std.debug.print("{{ 0 }},\n", .{});
                std.debug.print("{any},\n", .{val.name});
            }
            module_write(val.algebraic_type);
        },
        else => |v| @compileLog(v, val),
    }
}

test {
    const moduleDef: RawModuleDefV9 = std.mem.zeroes(RawModuleDefV9);
    module_write(moduleDef);
}

export fn __describe_module__(description: BytesSink) void {
    console_log(0, null, 0, null, 0, 0, "Hello from Zig!", 15);
    
    const moduleDef: RawModuleDefV9 = std.mem.zeroes(RawModuleDefV9);
    //moduleDef.

    // We need this explicit cast here to make `ToBytes` understand the types correctly.
    //RawModuleDef versioned = new RawModuleDef.V9(moduleDef);
    //var moduleBytes = IStructuralReadWrite.ToBytes(new RawModuleDef.BSATN(), versioned);
    //description.Write(moduleBytes);
    module_write(moduleDef);


    write_to_sink(description, &bytes);
}

export fn __call_reducer__(
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
    _ = id;
    _ = sender_0;
    _ = sender_1;
    _ = sender_2;
    _ = sender_3;
    _ = conn_id_0;
    _ = conn_id_1;
    _ = timestamp;
    _ = args;
    _ = err;

    return 0;
}

const ReducerContext = anyopaque;

var module: RawModuleDefV9 = .{};

const ReducerFn = fn(*ReducerContext) void;

comptime {
    for(@typeInfo(@This()).@"struct".decls) |decl| {
        const field = @field(@This(), decl.name);
        if(@typeInfo(@TypeOf(field)) != .@"fn") continue;
        if(@TypeOf(field) != ReducerFn) continue;
        
        @compileLog(.{field});
    }
}

pub fn init(_ctx: *ReducerContext) void {
    // Called when the module is initially published
    _ = _ctx;
    console_log(0, null, 0, null, 0, 0, "Hello, init!", 12);
}