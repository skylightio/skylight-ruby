#ifndef __SKYLIGHT_H__
#define __SKYLIGHT_H__

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

/**
 * Rust types
 */

typedef struct {
  size_t fill;    // in bytes; if zero, heapified
  size_t alloc;   // in bytes
  uint8_t data[0];
} rust_str;

typedef struct {
  char * data;
  long len;
} RustSlice;

typedef struct {
  uint8_t discrim;
  RustSlice slice;
} OptionRustSlice;

typedef rust_str * RustString;
typedef RustString RustVector;

/**
 * Externed Rust functions from libskylight
 */

typedef void * RustHello;
typedef void * RustError;
typedef void * RustTrace;
typedef void * RustBatch;

void factory();

// Rust skylight_hello prototypes
bool skylight_hello_new(RustSlice, uint32_t, RustHello*);
bool skylight_hello_free(RustHello);
bool skylight_hello_load(RustSlice, RustHello*);
bool skylight_hello_cmd_add(RustHello, RustSlice);
bool skylight_hello_get_version(RustHello, RustSlice*);
bool skylight_hello_cmd_length(RustHello, uint32_t*);
bool skylight_hello_get_cmd(RustHello, int, RustSlice*);
bool skylight_hello_serialize_into_new_buffer(RustHello, RustString*);
bool skylight_high_res_time(uint64_t*);

// Rust skylight_trace prototypes
bool skylight_trace_new(uint64_t, RustSlice, RustTrace*);
bool skylight_trace_free(RustTrace);
bool skylight_trace_name_from_serialized_into_new_buffer(RustSlice, RustString*);
bool skylight_trace_get_started_at(RustTrace, uint64_t*);
bool skylight_trace_set_name(RustTrace, RustSlice);
bool skylight_trace_get_name(RustTrace, RustSlice*);
bool skylight_trace_get_uuid(RustTrace, RustSlice*);
bool skylight_trace_start_span(RustTrace, uint64_t, RustSlice, uint32_t*);
bool skylight_trace_stop_span(RustTrace, uint32_t, uint64_t);
bool skylight_trace_serialize_into_new_buffer(RustTrace, RustString*);
bool skylight_trace_span_set_title(RustTrace, uint64_t, RustSlice);
bool skylight_trace_span_set_description(RustTrace, uint64_t, RustSlice);

// Trace annotation methods
bool skylight_trace_add_annotation_int(RustTrace, uint32_t, uint32_t*, RustSlice*, int64_t);
bool skylight_trace_add_annotation_double(RustTrace, uint32_t, uint32_t*, RustSlice*, double);
bool skylight_trace_add_annotation_string(RustTrace, uint32_t, uint32_t*, RustSlice*, RustSlice);
bool skylight_trace_add_annotation_nested(RustTrace, uint32_t, uint32_t*, RustSlice*, uint32_t*);

// Batch methods
bool skylight_batch_new(uint32_t, RustString, RustBatch*);
bool skylight_batch_free(RustBatch);
bool skylight_batch_set_endpoint_count(RustBatch, RustSlice, uint64_t);
bool skylight_batch_move_in(RustBatch, RustString);
bool skylight_batch_serialize_into_new_buffer(RustBatch, RustString*);

// Error methods
bool skylight_error_new(RustSlice, RustSlice, RustError*);
bool skylight_error_free(RustError);
bool skylight_error_load(RustSlice, RustError*);
bool skylight_error_get_group(RustError, RustSlice*);
bool skylight_error_get_description(RustError, RustSlice*);
bool skylight_error_get_details(RustError, RustSlice*);
bool skylight_error_set_details(RustError, RustSlice);
bool skylight_error_serialize_into_new_buffer(RustError, RustString*);

void skylight_free_buf(RustString);

#endif
