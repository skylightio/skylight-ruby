#import "ruby.h"
#import "direwolf.h"

VALUE rb_mTilde;
VALUE rb_cInstrumenter;
VALUE rb_cTrace;
VALUE rb_eTildeError;
VALUE rb_mUtil;

/*
 * Deallocator function. Called by ruby when the Instrumenter ruby object gets
 * garbage collected.
 */
static void
Instrumenter_dealloc(dw_instrumenter_t inst)
{
  dw_instrumenter_destroy(inst);
}

static dw_instrumenter_t
Instrumenter_get(VALUE v)
{
  dw_instrumenter_t inst;
  Data_Get_Struct(v, void, inst);
  return inst;
}

static VALUE
Instrumenter_allocate(VALUE self)
{
  dw_instrumenter_t inst = dw_instrumenter_init();
  return Data_Wrap_Struct(rb_cInstrumenter, 0, Instrumenter_dealloc, inst);
}

static VALUE
Instrumenter_start(VALUE self)
{
  dw_instrumenter_t inst = Instrumenter_get(self);
  dw_instrumenter_start(inst);
  return Qnil;
}

static VALUE
Instrumenter_shutdown(VALUE self)
{
  dw_instrumenter_t inst = Instrumenter_get(self);
  dw_instrumenter_shutdown(inst);
  return Qnil;
}

static dw_trace_t
Trace_get(VALUE v)
{
  dw_trace_t t;
  Data_Get_Struct(v, void, t);
  return t;
}

static void
Trace_dealloc(dw_trace_t trace) {
  dw_trace_destroy(trace);
}

static VALUE
Trace_allocate(VALUE self) {
  dw_trace_t trace = dw_trace_init();
  return Data_Wrap_Struct(rb_cTrace, 0, Trace_dealloc, trace);
}

static VALUE
Trace_record(VALUE self, VALUE cat, VALUE desc, VALUE annot) {
  dw_span_t span;

  if (TYPE(cat) != T_STRING) {
    rb_raise(rb_eTildeError, "trace category must instance of String");
    return Qnil;
  }

  if (cat != Qnil && TYPE(cat) != T_STRING) {
    rb_raise(rb_eTildeError, "trace description must be instance of String");
    return Qnil;
  }

  span.category = RSTRING_PTR(cat);
  span.category_len = RSTRING_LEN(cat);

  dw_trace_record(Trace_get(self), &span);

  return Qnil;
}

static VALUE
Trace_start(VALUE self, VALUE c, VALUE desc, VALUE annot) {
  return Qnil;
}

static VALUE
Trace_stop(VALUE self) {
  return Qnil;
}

static VALUE
Util_generate_request_id(VALUE self) {
  dw_request_id_t request_id;
  char request_id_s[DW_REQUEST_ID_LENGTH + 1];

  dw_generate_request_id(request_id);
  dw_request_id_to_string(request_id, request_id_s);

  return rb_str_new2(request_id_s);
}

void
Init_direwolf_native() {
  rb_mTilde = rb_define_module("Tilde");

  rb_eTildeError = rb_define_class_under(rb_mTilde, "Error", rb_eRuntimeError);

  /*
   * Define methods on Subscriber
   */
  rb_cInstrumenter = rb_define_class_under(rb_mTilde, "Instrumenter", rb_cObject);
  rb_define_singleton_method(rb_cInstrumenter, "__allocate", Instrumenter_allocate, 0);

  rb_define_method(rb_cInstrumenter, "__start",    Instrumenter_start,    0);
  rb_define_method(rb_cInstrumenter, "__shutdown", Instrumenter_shutdown, 0);

  /*
   * Define methods on Trace
   */
  rb_cTrace = rb_define_class_under(rb_mTilde, "Trace", rb_cObject);
  rb_define_singleton_method(rb_cTrace, "__allocate", Trace_allocate, 0);

  rb_define_method(rb_cTrace, "__record", Trace_record, 3);
  rb_define_method(rb_cTrace, "__start",  Trace_start,  3);
  rb_define_method(rb_cTrace, "__stop",   Trace_stop,   0);

  /*
   * Define methods on Util
   */
  rb_mUtil = rb_define_module_under(rb_mTilde, "Util");
  rb_define_module_function(rb_mUtil, "__generate_request_id", Util_generate_request_id, 0);
}
