// Copyright 2025 Tyler Peterson, Licensed under MPL-2.0

const spacetime = @import("../spacetime.zig");

const BytesSink = spacetime.BytesSink;
const BytesSource = spacetime.BytesSource;
const TableId = spacetime.TableId;
const RowIter = spacetime.RowIter;
const IndexId = spacetime.IndexId;
const ColId = spacetime.ColId;

extern "spacetime_10.0" fn bytes_sink_write(sink: BytesSink, buffer_ptr: [*c]const u8, buffer_len_ptr: *usize) u16;
extern "spacetime_10.0" fn bytes_source_read(source: BytesSource, buffer_ptr: [*c]u8, buffer_len_ptr: *usize) i16;
extern "spacetime_10.0" fn table_id_from_name(name: [*c]const u8, name_len: usize, out: *TableId) u16;
extern "spacetime_10.0" fn datastore_insert_bsatn(table_id: TableId, row_ptr: [*c]const u8, row_len_ptr: *usize) u16;
extern "spacetime_10.0" fn row_iter_bsatn_advance(iter: RowIter, buffer_ptr: [*c]u8, buffer_len_ptr: *usize) i16;
extern "spacetime_10.0" fn datastore_table_scan_bsatn(table_id: TableId, out: [*c]RowIter) u16;
extern "spacetime_10.0" fn index_id_from_name(name_ptr: [*c]const u8, name_len: usize, out: *IndexId) u16;
extern "spacetime_10.0" fn datastore_index_scan_range_bsatn( index_id: IndexId, prefix_ptr: [*c]const u8, prefix_len: usize, prefix_elems: ColId, rstart_ptr: [*c]const u8, rstart_len: usize, rend_ptr: [*c]const u8, rend_len: usize, out: *RowIter) u16;

pub fn tableIdFromName(name: []const u8, out: *TableId) u16 {
    return spacetime.retMap(table_id_from_name(name.ptr, name.len, out));
}

pub fn datastoreTableScanBsatn(table_id: TableId, out: [*c]RowIter) u16 {
    return spacetime.retMap(datastore_table_scan_bsatn(table_id, out));
}

pub fn indexIdFromName(name: []const u8, out: *IndexId) u16 {
    return spacetime.retMap(index_id_from_name(name.ptr, name.len, out));
}

pub fn datastoreIndexScanRangeBsatn( index_id: IndexId, prefix: []const u8, prefix_elems: ColId, rstart: []const u8, rend: []const u8, out: *RowIter) u16 {
    return spacetime.retMap(datastore_index_scan_range_bsatn( index_id, prefix.ptr, prefix.len, prefix_elems, rstart.ptr, rstart.len, rend.ptr, rend.len, out));
}
