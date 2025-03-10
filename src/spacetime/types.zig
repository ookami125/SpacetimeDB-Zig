pub const Str = []const u8;

pub const SumTypeVariant = struct {
    name: ?Str,
    algebraic_type: AlgebraicType,
};

pub const SumType = struct {
    variants: []const SumTypeVariant,
};

pub const ArrayType = struct {
    /// The base type every element of the array has.
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
    name: ?Str,
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

pub const ReducerContext = struct {
    indentity: u256,
    timestamp: u64,
    connection_id: u128,

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
