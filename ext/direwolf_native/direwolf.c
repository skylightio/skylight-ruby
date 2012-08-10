#import "ruby.h"
#import "direwolf.h"

VALUE rb_mTilde;
VALUE rb_cInstrumenter;
VALUE rb_cTracer;
VALUE rb_eTildeError;
VALUE rb_mUtil;

/*
 * Deallocator function. Called by ruby when the Instrumenter ruby object gets
 * garbage collected.
 */
static void
Instrumenter_dealloc(dw_instrumenter_t inst) {
  dw_instrumenter_destroy(inst);
}

static VALUE
Instrumenter_allocate(VALUE self) {
  dw_instrumenter_t inst = dw_instrumenter_init();
  return Data_Wrap_Struct(rb_cInstrumenter, 0, Instrumenter_dealloc, inst);
}

static dw_tracer_t
Tracer_get(VALUE v) {
  dw_tracer_t t;
  Data_Get_Struct(v, void, t);
  return t;
}

static void
Tracer_dealloc(dw_tracer_t tracer) {
  dw_tracer_destroy(tracer);
}

static VALUE
Tracer_allocate(VALUE self) {
  dw_tracer_t tracer = dw_tracer_init();
  return Data_Wrap_Struct(rb_cTracer, 0, Tracer_dealloc, tracer);
}

static VALUE
Tracer_record(VALUE self, VALUE cat, VALUE desc, VALUE annot) {
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

  dw_tracer_record(Tracer_get(self), &span);

  return Qnil;
}

static VALUE
Tracer_start(VALUE self, VALUE c, VALUE desc, VALUE annot) {
  return Qnil;
}

static VALUE
Tracer_stop(VALUE self) {
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

  /*
   * Define methods on Tracer
   */
  rb_cTracer = rb_define_class_under(rb_mTilde, "Tracer", rb_cObject);
  rb_define_singleton_method(rb_cTracer, "__allocate", Tracer_allocate, 0);

  rb_define_method(rb_cTracer, "__record", Tracer_record, 3);
  rb_define_method(rb_cTracer, "__start",  Tracer_start,  3);
  rb_define_method(rb_cTracer, "__stop",   Tracer_stop,   0);

  /*
   * Define methods on Util
   */
  rb_mUtil = rb_define_module_under(rb_mTilde, "Util");
  rb_define_module_function(rb_mUtil, "__generate_request_id", Util_generate_request_id, 0);
}
