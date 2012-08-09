#import "ruby.h"
#import "direwolf.h"

static VALUE Util_generate_request_id(VALUE self) {
  dw_request_id_t request_id;
  char request_id_s[DW_REQUEST_ID_LENGTH + 1];

  dw_generate_request_id(request_id);
  dw_request_id_to_string(request_id, request_id_s);

  return rb_str_new2(request_id_s);
}

void Init_direwolf_native() {
  VALUE rb_mTilde, rb_cSubscriber, rb_mUtil;

  rb_mTilde = rb_define_module("Tilde");

  /*
   * Define methods on Subscriber
   */
  rb_cSubscriber = rb_define_class_under(rb_mTilde, "Subscriber", rb_cObject);

  /*
   * Define methods on Util
   */
  rb_mUtil = rb_define_module_under(rb_mTilde, "Util");

  rb_define_singleton_method(rb_mUtil, "__generate_request_id", Util_generate_request_id, 0);
}
