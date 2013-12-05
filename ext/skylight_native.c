#include <ruby.h>

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

#define My_Struct(name, Type, msg)                \
  Get_Struct(name, self, Type, msg);              \

#define Transfer_Struct(name, Type, msg)          \
  My_Struct(name, Type, msg);                     \
  DATA_PTR(self) = NULL;                          \

#define Get_Struct(name, obj, Type, msg)          \
  Type name;                                      \
  Data_Get_Struct(obj, Type, name);               \
  if (name == NULL) {                             \
    rb_raise(rb_eRuntimeError, "%s", msg);        \
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
#define VEC2STR(string) ({ RustString s = (string); VALUE ret = rb_str_new((char *)s->data, s->fill); skylight_free_buf(s); ret; })
#define SLICE2STR(slice) ({ RustSlice s = (slice); rb_str_new(s.data, s.len); })

/**
 * Externed Rust functions from libskylight
 */

typedef void * RustHello;
typedef void * RustTrace;
typedef void * RustAnnotationBuilder;

void factory();


// Rust skylight_hello prototypes
RustHello skylight_hello_new(RustString, int);
RustSlice skylight_hello_get_version(RustHello);
int skylight_hello_get_cmd(RustHello, int, RustSlice*);
RustString skylight_hello_serialize(RustHello);
void skylight_hello_cmd_add(RustHello, RustString);
uint64_t skylight_high_res_time();

// Rust skylight_trace prototypes
RustTrace skylight_trace_new(uint64_t);
uint64_t skylight_trace_get_started_at(RustTrace);
void skylight_trace_set_name(RustTrace, RustString);
RustSlice skylight_trace_get_name(RustTrace);
void skylight_trace_set_uuid(RustTrace, RustString);
RustSlice skylight_trace_get_uuid(RustTrace);
uint64_t skylight_trace_start_span(RustTrace, uint64_t, RustString);
void skylight_trace_stop_span(RustString, uint64_t, uint64_t);
RustString skylight_trace_serialize(RustTrace);
void skylight_trace_span_set_title(RustTrace, uint64_t, RustString);
void skylight_trace_span_set_description(RustTrace, uint64_t, RustString);

// Trace annotation methods
uint64_t skylight_trace_add_annotation_int(RustTrace, uint64_t, uint64_t*, RustString, uint64_t);
uint64_t skylight_trace_add_annotation_double(RustTrace, uint64_t, uint64_t*, RustString, double);
uint64_t skylight_trace_add_annotation_string(RustTrace, uint64_t, uint64_t*, RustString, RustString);
uint64_t skylight_trace_add_annotation_nested(RustTrace, uint64_t, uint64_t*, RustString);

void skylight_free_buf(RustString);

/**
 * Convert Ruby String to a Rust String
 */

RustString skylight_cstr_to_rust_str(char *, int);

static RustString ruby_string_to_rust_string(VALUE string) {
  int len = RSTRING_LEN(string);
  char *ptr = RSTRING_PTR(string);

  return skylight_cstr_to_rust_str(ptr, len);
}

#define STR2RUST(string) ruby_string_to_rust_string(string)

/**
 * Ruby types defined here
 */

VALUE rb_mSkylight;
VALUE rb_mUtil;
VALUE rb_cClock;
VALUE rb_cHello;
VALUE rb_cTrace;
VALUE rb_cAnnotationBuilder;

/**
 * class Skylight::Util::Clock
 */

static VALUE clock_high_res_time(VALUE self) {
  return UINT2NUM(skylight_high_res_time());
}

/**
 * class Skylight::Hello
 */

static void hello_dealloc(RustHello hello) {
  // noop for now
}

static VALUE hello_new(VALUE klass, VALUE version, VALUE config) {
  RustHello hello;

  CHECK_TYPE(version, T_STRING);
  CHECK_TYPE(config, T_FIXNUM);

  hello = skylight_hello_new(STR2RUST(version), FIX2INT(config));

  return Data_Wrap_Struct(rb_cHello, 0, hello_dealloc, hello);
}

static const char* freedHello = "You can't do anything with a Hello once it's been serialized";

static VALUE hello_get_version(VALUE self) {
  My_Struct(hello, RustHello, freedHello);

  return SLICE2STR(skylight_hello_get_version(hello));
}

static VALUE hello_add_cmd_part(VALUE self, VALUE part) {
  My_Struct(hello, RustHello, freedHello);

  CHECK_TYPE(part, T_STRING);

  skylight_hello_cmd_add(hello, STR2RUST(part));
  return Qnil;
}

static VALUE hello_cmd_get(VALUE self, VALUE rb_off) {
  int hasValue, off;
  RustSlice slice;
  My_Struct(hello, RustHello, freedHello);

  CHECK_TYPE(rb_off, T_FIXNUM);
  off = FIX2INT(rb_off);

  hasValue = skylight_hello_get_cmd(hello, off, &slice);

  if (hasValue) return SLICE2STR(slice);
  return Qnil;
}

static VALUE hello_serialize(VALUE self) {
  RustString serialized;
  My_Struct(hello, RustHello, freedHello);

  serialized = skylight_hello_serialize(hello);
  return VEC2STR(serialized);
}

/**
 * Skylight::Trace
 */

static const char* freedTrace = "You can't do anything with a Trace once it's been serialized";

static void trace_dealloc(RustTrace hello) {
  // noop for now
}

static VALUE trace_new(VALUE self, VALUE started_at) {
  RustTrace trace = skylight_trace_new(FIX2UINT(started_at));
  return Data_Wrap_Struct(rb_cTrace, 0, trace_dealloc, trace);
}

static VALUE trace_get_started_at(VALUE self) {
  My_Struct(trace, RustTrace, freedTrace);
  return LONG2NUM(skylight_trace_get_started_at(trace));
}

static VALUE trace_set_name(VALUE self, VALUE name) {
  My_Struct(trace, RustTrace, freedTrace);
  skylight_trace_set_name(trace, STR2RUST(name));
  return Qnil;
}

static VALUE trace_get_name(VALUE self) {
  My_Struct(trace, RustTrace, freedTrace);
  return SLICE2STR(skylight_trace_get_name(trace));
}

static VALUE trace_set_uuid(VALUE self, VALUE name) {
  My_Struct(trace, RustTrace, freedTrace);
  skylight_trace_set_uuid(trace, STR2RUST(name));
  return Qnil;
}

static VALUE trace_get_uuid(VALUE self) {
  My_Struct(trace, RustTrace, freedTrace);
  return SLICE2STR(skylight_trace_get_uuid(trace));
}

static VALUE trace_start_span(VALUE self, VALUE time, VALUE category) {
  int span;
  My_Struct(trace, RustTrace, freedTrace);

  CHECK_TYPE(time, T_FIXNUM);
  CHECK_TYPE(category, T_STRING);

  span = skylight_trace_start_span(trace, FIX2UINT(time), STR2RUST(category));

  return INT2FIX(span);
}

static VALUE trace_stop_span(VALUE self, VALUE span_index, VALUE time) {
  My_Struct(trace, RustTrace, freedTrace);

  CHECK_TYPE(time, T_FIXNUM);
  CHECK_TYPE(span_index, T_FIXNUM);

  skylight_trace_stop_span(trace, FIX2UINT(span_index), FIX2UINT(time));
  return Qnil;
}

static VALUE trace_span_set_title(VALUE self, VALUE index, VALUE title) {
  My_Struct(trace, RustTrace, freedTrace);

  CHECK_TYPE(index, T_FIXNUM);
  CHECK_TYPE(title, T_STRING);

  skylight_trace_span_set_title(trace, FIX2INT(index), STR2RUST(title));
  return Qnil;
}

static VALUE trace_span_set_description(VALUE self, VALUE index, VALUE description) {
  My_Struct(trace, RustTrace, freedTrace);

  CHECK_TYPE(index, T_FIXNUM);
  CHECK_TYPE(description, T_STRING);

  skylight_trace_span_set_description(trace, FIX2INT(index), STR2RUST(description));
  return Qnil;
}

static VALUE trace_serialize(VALUE self) {
  Transfer_Struct(trace, RustTrace, freedTrace);

  return VEC2STR(skylight_trace_serialize(trace));
}

static VALUE trace_span_add_annotation(VALUE self, VALUE rb_span_id, VALUE parent, VALUE rb_key, VALUE value) {
  uint64_t *parent_id = NULL;
  RustString key = NULL;
  uint64_t new_id, parent_int;

  My_Struct(trace, RustTrace, freedTrace);

  CHECK_TYPE(rb_span_id, T_FIXNUM);
  uint64_t span_id = FIX2INT(rb_span_id);

  if (parent != Qnil) {
    CHECK_TYPE(parent, T_FIXNUM);
    parent_int = FIX2INT(parent);
    parent_id = &parent_int;
  }

  if (rb_key != Qnil) {
    CHECK_TYPE(rb_key, T_STRING);
    key = STR2RUST(rb_key);
  }

  if (TYPE(value) == T_FIXNUM) {
    skylight_trace_add_annotation_int(trace, span_id, parent_id, key, FIX2INT(value));
  } else if (TYPE(value) == T_FLOAT) {
    skylight_trace_add_annotation_double(trace, span_id, parent_id, key, NUM2DBL(value));
  } else if (TYPE(value) == T_STRING) {
    skylight_trace_add_annotation_string(trace, span_id, parent_id, key, STR2RUST(value));
  } else if (TYPE(value) == T_SYMBOL && value == ID2SYM(rb_intern("nested"))) {
    new_id = skylight_trace_add_annotation_nested(trace, span_id, parent_id, key);
    return INT2FIX(new_id);
  }

  return Qnil;
}

void Init_skylight_native() {
  rb_mSkylight = rb_define_module("Skylight");
  rb_mUtil  = rb_define_module_under(rb_mSkylight, "Util");

  rb_cClock = rb_define_class_under(rb_mUtil, "Clock", rb_cObject);
  rb_define_method(rb_cClock, "native_hrtime", clock_high_res_time, 0);

  rb_cHello = rb_define_class_under(rb_mSkylight, "Hello", rb_cObject);
  rb_define_singleton_method(rb_cHello, "native_new", hello_new, 2);
  rb_define_method(rb_cHello, "native_get_version", hello_get_version, 0);
  rb_define_method(rb_cHello, "native_add_cmd_part", hello_add_cmd_part, 1);
  rb_define_method(rb_cHello, "native_cmd_get", hello_cmd_get, 1);
  rb_define_method(rb_cHello, "native_serialize", hello_serialize, 0);

  rb_cTrace = rb_define_class_under(rb_mSkylight, "Trace", rb_cObject);
  rb_define_singleton_method(rb_cTrace, "native_new", trace_new, 1);
  /*rb_define_singleton_method(rb_cTrace, "native_load", trace_load, 1);*/
  rb_define_method(rb_cTrace, "native_get_started_at", trace_get_started_at, 0);
  rb_define_method(rb_cTrace, "native_get_name", trace_get_name, 0);
  rb_define_method(rb_cTrace, "native_set_name", trace_set_name, 1);
  rb_define_method(rb_cTrace, "native_get_uuid", trace_get_uuid, 0);
  rb_define_method(rb_cTrace, "native_set_uuid", trace_set_uuid, 1);
  rb_define_method(rb_cTrace, "native_serialize", trace_serialize, 0);
  rb_define_method(rb_cTrace, "native_start_span", trace_start_span, 2);
  rb_define_method(rb_cTrace, "native_stop_span", trace_stop_span, 2);
  rb_define_method(rb_cTrace, "native_span_set_title", trace_span_set_title, 2);
  rb_define_method(rb_cTrace, "native_span_set_description", trace_span_set_description, 2);
  rb_define_method(rb_cTrace, "native_span_add_annotation", trace_span_add_annotation, 4);
}
