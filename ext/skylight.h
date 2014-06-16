#ifndef __SKYLIGHT_H__
#define __SKYLIGHT_H__

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include <rust_support/ruby.h>

/**
 * TODO: This is copied from rust_support
 */

bool skylight_string_as_slice(RustString, RustSlice*);

#define SKYLIGHT_RUSTSTR2STR(string)          \
  ({                                 \
    RustString s = (string);         \
    RustSlice slice;                  \
    CHECK_FFI(skylight_string_as_slice(s, &slice), "Couldn't convert String to &str"); \
    SLICE2STR(slice);                    \
  })

/**
 * Externed Rust functions from libskylight
 */

typedef void * RustSerializer;
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
bool skylight_hello_get_cmd(RustHello, uint32_t, RustSlice*);
bool skylight_hello_get_serializer(RustHello, RustSerializer*);
bool skylight_hello_serialize(RustHello, RustSerializer, RustSlice);
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
bool skylight_trace_span_set_title(RustTrace, uint64_t, RustSlice);
bool skylight_trace_span_set_description(RustTrace, uint64_t, RustSlice);
bool skylight_trace_get_serializer(RustTrace, RustSerializer*);
bool skylight_trace_serialize(RustTrace, RustSerializer, RustSlice);

// Batch methods
bool skylight_batch_new(uint32_t, RustSlice*, RustBatch*);
bool skylight_batch_free(RustBatch);
bool skylight_batch_set_endpoint_count(RustBatch, RustSlice, uint64_t);
bool skylight_batch_move_in(RustBatch, RustSlice);
bool skylight_batch_get_serializer(RustBatch, RustSerializer*);
bool skylight_batch_serialize(RustBatch, RustSerializer, RustSlice);

// Error methods
bool skylight_error_new(RustSlice, RustSlice, RustError*);
bool skylight_error_free(RustError);
bool skylight_error_load(RustSlice, RustError*);
bool skylight_error_get_group(RustError, RustSlice*);
bool skylight_error_get_description(RustError, RustSlice*);
bool skylight_error_get_details(RustError, RustSlice*);
bool skylight_error_set_details(RustError, RustSlice);
bool skylight_error_get_serializer(RustError, RustSerializer*);
bool skylight_error_serialize(RustError, RustSerializer, RustSlice);

bool skylight_serializer_get_serialized_size(RustSerializer, size_t*);
bool skylight_serializer_free(RustSerializer);

#endif
