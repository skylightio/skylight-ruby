#include <ruby.h>
#include <stdbool.h>

/**
 * Ruby helpers
 */

#define CHECK_TYPE(VAL, T)                        \
  do {                                            \
    if (TYPE(VAL) != T) {                         \
      rb_raise(rb_eArgError, #VAL " is not " #T); \
      return Qnil;                                \
    }                                             \
  } while(0)                                      \

#define CHECK(EXPR, string)                       \
  do {                                            \
    if (!({ EXPR; })) {                           \
      rb_raise(rb_eArgError, string);             \
      return Qnil;                                \
    }                                             \
  } while(0)                                      \

#define CHECK_NUMERIC(VAL)                        \
  CHECK(VAL, #VAL " is not numeric")              \

#define My_Struct(name, Type, msg)                \
  Get_Struct(name, self, Type, msg);              \

#define Transfer_My_Struct(name, Type, msg)       \
  My_Struct(name, Type, msg);                     \
  DATA_PTR(self) = NULL;                          \

#define Transfer_Struct(name, obj, Type, msg)     \
  Get_Struct(name, obj, Type, msg);               \
  DATA_PTR(obj) = NULL;                           \

#define Get_Struct(name, obj, Type, msg)          \
  Type name;                                      \
  Data_Get_Struct(obj, Type, name);               \
  if (name == NULL) {                             \
    rb_raise(rb_eRuntimeError, "%s", msg);        \
  }                                               \

#define CHECK_FFI(success, message)               \
  {                                               \
    if (!(success))                               \
      rb_raise(rb_eRuntimeError, message);        \
  }                                               \

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

typedef rust_str * RustString;
#define VEC2STR(string) ({ RustString s = (string); VALUE ret = rb_str_new((char *)s->data, s->fill); ret; })
#define SLICE2STR(slice) ({ RustSlice s = (slice); rb_str_new(s.data, s.len); })
#define STR2SLICE(string) ({ RustSlice s; VALUE rb_str = (string); s.data = RSTRING_PTR(rb_str); s.len = RSTRING_LEN(rb_str); s; })

#define UnwrapOption(T, val, transform) ({ T * v = (val); VALUE ret; if (v == NULL) ret = Qnil; else ret = transform(*v); ret; })

typedef struct {
  uint8_t discrim;
  RustSlice slice;
} OptionRustSlice;

#define IsNone(val) val.discrim == 0

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
bool skylight_trace_load(RustSlice, RustTrace*);
bool skylight_trace_name_from_serialized_into_new_buffer(RustSlice, RustSlice*);
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

/**
 * Convert Ruby String to a Rust String
 */

RustString skylight_slice_to_owned(RustSlice);
RustString skylight_bytes_to_new_vec(uint8_t*, uint64_t);

#define STR2RUST(string) ({ VALUE rb_str = (string); skylight_bytes_to_new_vec((uint8_t*)RSTRING_PTR(rb_str), RSTRING_LEN(rb_str)); })

/**
 * Ruby types defined here
 */

VALUE rb_mSkylight;
VALUE rb_mUtil;
VALUE rb_cClock;
VALUE rb_cHello;
VALUE rb_cError;
VALUE rb_cTrace;
VALUE rb_cBatch;

/**
 * class Skylight::Util::Clock
 */

static VALUE clock_high_res_time(VALUE self) {
  uint64_t time;
  CHECK_FFI(skylight_high_res_time(&time), "Could not get high-res time");
  return ULL2NUM(time);
}

/**
 * class Skylight::Hello
 */

static VALUE hello_new(VALUE klass, VALUE version, VALUE config) {
  RustHello hello;

  CHECK_TYPE(version, T_STRING);
  CHECK_TYPE(config, T_FIXNUM);

  CHECK_FFI(skylight_hello_new(STR2SLICE(version), FIX2INT(config), &hello), "could not create new Hello");

  return Data_Wrap_Struct(rb_cHello, NULL, skylight_hello_free, hello);
}

static VALUE hello_load(VALUE self, VALUE protobuf) {
  CHECK_TYPE(protobuf, T_STRING);

  RustHello hello;

  CHECK_FFI(skylight_hello_load(STR2SLICE(protobuf), &hello), "Could not load Hello");

  return Data_Wrap_Struct(rb_cHello, NULL, skylight_hello_free, hello);
}

static const char* freedHello = "You can't do anything with a Hello once it's been serialized";

static VALUE hello_get_version(VALUE self) {
  RustSlice slice;

  My_Struct(hello, RustHello, freedHello);

  CHECK_FFI(skylight_hello_get_version(hello, &slice), "could not get version from Hello");

  return SLICE2STR(slice);
}

static VALUE hello_cmd_length(VALUE self) {
  My_Struct(hello, RustHello, freedHello);

  uint32_t length;

  CHECK_FFI(skylight_hello_cmd_length(hello, &length), "Could not get length of Hello commands");

  return UINT2NUM(length);
}

static VALUE hello_add_cmd_part(VALUE self, VALUE rb_string) {
  My_Struct(hello, RustHello, freedHello);

  CHECK_TYPE(rb_string, T_STRING);

  CHECK_FFI(skylight_hello_cmd_add(hello, STR2SLICE(rb_string)), "Could not add command part to Hello");

  return Qnil;
}

static VALUE hello_cmd_get(VALUE self, VALUE rb_off) {
  int off;
  RustSlice slice;
  My_Struct(hello, RustHello, freedHello);

  CHECK_TYPE(rb_off, T_FIXNUM);
  off = FIX2INT(rb_off);

  CHECK_FFI(skylight_hello_get_cmd(hello, off, &slice), "Could not get command part from Hello");

  return SLICE2STR(slice);
}

static VALUE hello_serialize(VALUE self) {
  RustString serialized;
  Transfer_My_Struct(hello, RustHello, freedHello);

  CHECK_FFI(skylight_hello_serialize_into_new_buffer(hello, &serialized), "Could not serialize Hello");
  skylight_hello_free(hello);

  VALUE string = VEC2STR(serialized);
  skylight_free_buf(serialized);
  return string;
}

/**
 * class Skylight::Error
 */

static VALUE error_new(VALUE klass, VALUE group, VALUE description) {
  RustError error;

  CHECK_TYPE(group, T_STRING);
  CHECK_TYPE(description, T_STRING);

  CHECK_FFI(skylight_error_new(STR2SLICE(group), STR2SLICE(description), &error), "could not create new Error");

  return Data_Wrap_Struct(rb_cError, NULL, skylight_error_free, error);
}

static VALUE error_load(VALUE self, VALUE protobuf) {
  CHECK_TYPE(protobuf, T_STRING);

  RustError error;

  CHECK_FFI(skylight_error_load(STR2SLICE(protobuf), &error), "Could not load Error");

  return Data_Wrap_Struct(rb_cError, NULL, skylight_error_free, error);
}

static const char* freedError = "You can't do anything with a Error once it's been serialized";

static VALUE error_get_group(VALUE self) {
  RustSlice slice;

  My_Struct(error, RustError, freedError);

  CHECK_FFI(skylight_error_get_group(error, &slice), "could not get group from Error");

  return SLICE2STR(slice);
}

static VALUE error_get_description(VALUE self) {
  RustSlice slice;

  My_Struct(error, RustError, freedError);

  CHECK_FFI(skylight_error_get_description(error, &slice), "could not get description from Error");

  return SLICE2STR(slice);
}

static VALUE error_get_details(VALUE self) {
  RustSlice slice;

  My_Struct(error, RustError, freedError);

  CHECK_FFI(skylight_error_get_details(error, &slice), "could not get details from Error");

  return SLICE2STR(slice);
}

static VALUE error_set_details(VALUE self, VALUE details) {
  CHECK_TYPE(details, T_STRING);

  My_Struct(error, RustError, freedError);

  CHECK_FFI(skylight_error_set_details(error, STR2SLICE(details)), "could not set Error details");

  return Qnil;
}

static VALUE error_serialize(VALUE self) {
  RustString serialized;
  Transfer_My_Struct(error, RustError, freedError);

  CHECK_FFI(skylight_error_serialize_into_new_buffer(error, &serialized), "Could not serialize Error");
  skylight_error_free(error);

  VALUE string = VEC2STR(serialized);
  skylight_free_buf(serialized);
  return string;
}

/**
 * Skylight::Trace
 */

static const char* freedTrace = "You can't do anything with a Trace once it's been serialized or moved into a Batch";

static VALUE trace_new(VALUE self, VALUE started_at, VALUE uuid) {
  CHECK_TYPE(started_at, T_FIXNUM);
  CHECK_TYPE(uuid, T_STRING);

  RustTrace trace;

  CHECK_FFI(skylight_trace_new(NUM2ULL(started_at), STR2SLICE(uuid), &trace), "Could not created Trace");

  return Data_Wrap_Struct(rb_cTrace, NULL, skylight_trace_free, trace);
}

static VALUE trace_load(VALUE self, VALUE protobuf) {
  CHECK_TYPE(protobuf, T_STRING);

  RustTrace trace;

  CHECK_FFI(skylight_trace_load(STR2SLICE(protobuf), &trace), "Could not load Trace");

  return Data_Wrap_Struct(rb_cTrace, NULL, skylight_trace_free, trace);
}

static VALUE trace_name_from_serialized(VALUE self, VALUE protobuf) {
  CHECK_TYPE(protobuf, T_STRING);

  RustSlice trace_name;

  CHECK_FFI(skylight_trace_name_from_serialized_into_new_buffer(STR2SLICE(protobuf), &trace_name), "Could not read name from serialized Trace");

  return SLICE2STR(trace_name);
}

static VALUE trace_get_started_at(VALUE self) {
  My_Struct(trace, RustTrace, freedTrace);

  uint64_t started_at;

  CHECK_FFI(skylight_trace_get_started_at(trace, &started_at), "Could not get Trace started_at");

  return ULL2NUM(started_at);
}

static VALUE trace_set_name(VALUE self, VALUE name) {
  CHECK_TYPE(name, T_STRING);

  My_Struct(trace, RustTrace, freedTrace);
  CHECK_FFI(skylight_trace_set_name(trace, STR2SLICE(name)), "Could not set Trace name");
  return Qnil;
}

static VALUE trace_get_name(VALUE self) {
  My_Struct(trace, RustTrace, freedTrace);

  RustSlice string;
  if (skylight_trace_get_name(trace, &string)) {
    return SLICE2STR(string);
  } else {
    return Qnil;
  }

  //return UnwrapOption(RustSlice, skylight_trace_get_name(trace), SLICE2STR);
}

static VALUE trace_get_uuid(VALUE self) {
  My_Struct(trace, RustTrace, freedTrace);

  RustSlice slice;

  CHECK_FFI(skylight_trace_get_uuid(trace, &slice), "Could not get uuid from Trace");

  return SLICE2STR(slice);
}

static VALUE trace_start_span(VALUE self, VALUE time, VALUE category) {
  uint32_t span;
  My_Struct(trace, RustTrace, freedTrace);

  CHECK_NUMERIC(time);
  CHECK_TYPE(category, T_STRING);

  CHECK_FFI(skylight_trace_start_span(trace, NUM2ULL(time), STR2SLICE(category), &span), "Could not start Span");

  return UINT2NUM(span);
}

static VALUE trace_stop_span(VALUE self, VALUE span_index, VALUE time) {
  My_Struct(trace, RustTrace, freedTrace);

  CHECK_NUMERIC(time);
  CHECK_TYPE(span_index, T_FIXNUM);

  CHECK_FFI(skylight_trace_stop_span(trace, FIX2UINT(span_index), NUM2ULL(time)), "Could not stop Span");

  return Qnil;
}

static VALUE trace_span_set_title(VALUE self, VALUE index, VALUE title) {
  My_Struct(trace, RustTrace, freedTrace);

  CHECK_TYPE(index, T_FIXNUM);
  CHECK_TYPE(title, T_STRING);

  CHECK_FFI(skylight_trace_span_set_title(trace, NUM2LL(index), STR2SLICE(title)), "Could not set Span title");

  return Qnil;
}

static VALUE trace_span_set_description(VALUE self, VALUE index, VALUE description) {
  My_Struct(trace, RustTrace, freedTrace);

  CHECK_TYPE(index, T_FIXNUM);
  CHECK_TYPE(description, T_STRING);

  CHECK_FFI(skylight_trace_span_set_description(trace, NUM2LL(index), STR2SLICE(description)), "Could not set Span description");
  return Qnil;
}

static VALUE trace_serialize(VALUE self) {
  Transfer_My_Struct(trace, RustTrace, freedTrace);

  RustString string;

  CHECK_FFI(skylight_trace_serialize_into_new_buffer(trace, &string), "Could not serialize Trace");
  skylight_trace_free(trace);

  VALUE rb_string = VEC2STR(string);
  skylight_free_buf(string);
  return rb_string;
}

static VALUE trace_span_add_annotation(VALUE self, VALUE rb_span_id, VALUE parent, VALUE rb_key, VALUE value) {
  uint32_t *parent_id = NULL;
  RustSlice rs_key;
  RustSlice *key = NULL;
  uint32_t new_id, parent_int;

  My_Struct(trace, RustTrace, freedTrace);

  CHECK_TYPE(rb_span_id, T_FIXNUM);
  uint32_t span_id = FIX2UINT(rb_span_id);

  if (parent != Qnil) {
    CHECK_TYPE(parent, T_FIXNUM);
    parent_int = FIX2UINT(parent);
    parent_id = &parent_int;
  }

  if (rb_key != Qnil) {
    CHECK_TYPE(rb_key, T_STRING);

    rs_key = STR2SLICE(rb_key);
    key = &rs_key;
  }

  if (TYPE(value) == T_FIXNUM) {
    CHECK_FFI(skylight_trace_add_annotation_int(trace, span_id, parent_id, key, NUM2LL(value)), "Could not add int annotation");
  } else if (TYPE(value) == T_FLOAT) {
    CHECK_FFI(skylight_trace_add_annotation_double(trace, span_id, parent_id, key, NUM2DBL(value)), "Could not add double annotation");
  } else if (TYPE(value) == T_STRING) {
    CHECK_FFI(skylight_trace_add_annotation_string(trace, span_id, parent_id, key, STR2SLICE(value)), "Could not add string annotation");
  } else if (TYPE(value) == T_SYMBOL && value == ID2SYM(rb_intern("nested"))) {
    CHECK_FFI(skylight_trace_add_annotation_nested(trace, span_id, parent_id, key, &new_id), "Could not add nested annotation");
    return ULL2NUM(new_id);
  } else {
    rb_raise(rb_eArgError, "You must pass an integer, string or :nested to native_span_add_annotation");
  }

  return Qnil;
}

/**
 * class Skylight::Batch
 */

static const char* freedBatch = "You can't do anything with a Batch once it's been serialized";

VALUE batch_new(VALUE klass, VALUE rb_timestamp, VALUE rb_hostname) {
  CHECK_NUMERIC(rb_timestamp);

  RustString hostname = NULL;
  uint32_t timestamp = NUM2ULONG(rb_timestamp);

  if (rb_hostname != Qnil) {
    CHECK_TYPE(rb_hostname, T_STRING);
    hostname = STR2RUST(rb_hostname);
  }

  RustBatch batch;

  CHECK_FFI(skylight_batch_new(timestamp, hostname, &batch), "Could not create Batch");

  return Data_Wrap_Struct(rb_cBatch, NULL, skylight_batch_free, batch);
}

VALUE batch_set_endpoint_count(VALUE self, VALUE rb_endpoint_name, VALUE rb_count) {
  CHECK_TYPE(rb_endpoint_name, T_STRING);
  CHECK_NUMERIC(rb_count);

  My_Struct(batch, RustBatch, freedBatch);

  CHECK_FFI(skylight_batch_set_endpoint_count(batch, STR2SLICE(rb_endpoint_name), NUM2ULL(rb_count)), "Could not set count for Endpoint in Batch");

  return Qnil;
}

VALUE batch_move_in(VALUE self, VALUE rb_string) {
  CHECK_TYPE(rb_string, T_STRING);

  My_Struct(batch, RustBatch, freedBatch);

  CHECK_FFI(skylight_batch_move_in(batch, STR2RUST(rb_string)), "Could not add serialized Trace to Batch");

  return Qnil;
}

VALUE batch_serialize(VALUE self) {
  Transfer_My_Struct(batch, RustBatch, freedBatch);

  RustString string;

  CHECK_FFI(skylight_batch_serialize_into_new_buffer(batch, &string), "Could not serialize Batch");
  skylight_batch_free(batch);

  VALUE rb_string = VEC2STR(string);
  skylight_free_buf(string);
  return rb_string;
}

void Init_skylight_native() {
  rb_mSkylight = rb_define_module("Skylight");
  rb_mUtil  = rb_define_module_under(rb_mSkylight, "Util");

  rb_cClock = rb_define_class_under(rb_mUtil, "Clock", rb_cObject);
  rb_define_method(rb_cClock, "native_hrtime", clock_high_res_time, 0);

  rb_cHello = rb_define_class_under(rb_mSkylight, "Hello", rb_cObject);
  rb_define_singleton_method(rb_cHello, "native_new", hello_new, 2);
  rb_define_singleton_method(rb_cHello, "native_load", hello_load, 1);
  rb_define_method(rb_cHello, "native_get_version", hello_get_version, 0);
  rb_define_method(rb_cHello, "native_cmd_length", hello_cmd_length, 0);
  rb_define_method(rb_cHello, "native_add_cmd_part", hello_add_cmd_part, 1);
  rb_define_method(rb_cHello, "native_cmd_get", hello_cmd_get, 1);
  rb_define_method(rb_cHello, "native_serialize", hello_serialize, 0);

  rb_cError = rb_define_class_under(rb_mSkylight, "Error", rb_cObject);
  rb_define_singleton_method(rb_cError, "native_new", error_new, 2);
  rb_define_singleton_method(rb_cError, "native_load", error_load, 1);
  rb_define_method(rb_cError, "native_get_group", error_get_group, 0);
  rb_define_method(rb_cError, "native_get_description", error_get_description, 0);
  rb_define_method(rb_cError, "native_get_details", error_get_details, 0);
  rb_define_method(rb_cError, "native_set_details", error_set_details, 1);
  rb_define_method(rb_cError, "native_serialize", error_serialize, 0);

  rb_cTrace = rb_define_class_under(rb_mSkylight, "Trace", rb_cObject);
  rb_define_singleton_method(rb_cTrace, "native_new", trace_new, 2);
  rb_define_singleton_method(rb_cTrace, "native_load", trace_load, 1);
  rb_define_singleton_method(rb_cTrace, "native_name_from_serialized", trace_name_from_serialized, 1);
  rb_define_method(rb_cTrace, "native_get_started_at", trace_get_started_at, 0);
  rb_define_method(rb_cTrace, "native_get_name", trace_get_name, 0);
  rb_define_method(rb_cTrace, "native_set_name", trace_set_name, 1);
  rb_define_method(rb_cTrace, "native_get_uuid", trace_get_uuid, 0);
  rb_define_method(rb_cTrace, "native_serialize", trace_serialize, 0);
  rb_define_method(rb_cTrace, "native_start_span", trace_start_span, 2);
  rb_define_method(rb_cTrace, "native_stop_span", trace_stop_span, 2);
  rb_define_method(rb_cTrace, "native_span_set_title", trace_span_set_title, 2);
  rb_define_method(rb_cTrace, "native_span_set_description", trace_span_set_description, 2);
  rb_define_method(rb_cTrace, "native_span_add_annotation", trace_span_add_annotation, 4);

  rb_cBatch = rb_define_class_under(rb_mSkylight, "Batch", rb_cObject);
  rb_define_singleton_method(rb_cBatch, "native_new", batch_new, 2);
  rb_define_method(rb_cBatch, "native_move_in", batch_move_in, 1);
  rb_define_method(rb_cBatch, "native_set_endpoint_count", batch_set_endpoint_count, 2);
  rb_define_method(rb_cBatch, "native_serialize", batch_serialize, 0);
}
