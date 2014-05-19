#include <ruby.h>
#include "skylight_test.h"

#ifdef HAVE_RUBY_ENCODING_H
#include <ruby/encoding.h>
#endif

VALUE rb_mSkylightTest;
VALUE rb_mNumeric;
VALUE rb_mStrings;
VALUE rb_mStructs;
VALUE rb_cPerson;

static VALUE numeric_multiply(VALUE klass, VALUE a, VALUE b) {
  CHECK_NUMERIC(a);
  CHECK_NUMERIC(b);

  uint64_t ret;

  CHECK_FFI(skylight_test_numeric_multiply(NUM2ULL(a), NUM2ULL(b), &ret), "could not multiply");

  return ULL2NUM(ret);
}

static VALUE strings_multiple(VALUE klass, VALUE input) {
  CHECK_TYPE(input, T_STRING);

  RustString string;

  CHECK_FFI(skylight_test_strings_reverse(STR2SLICE(input), &string), "could not reverse");

  return RUSTSTR2STR(string);
}

static const char* freedPerson = "You can't do anything with a Person once it is freed";

static VALUE person_new(VALUE klass, VALUE name, VALUE age) {
  CHECK_TYPE(name, T_STRING);
  CHECK_NUMERIC(age);

  RustPerson person;

  CHECK_FFI(skylight_test_person_new(STR2SLICE(name), NUM2ULL(age), &person), "could not create new Person");

  return Data_Wrap_Struct(rb_cPerson, NULL, skylight_test_person_free, person);
}

static VALUE person_get_name(VALUE self) {
  My_Struct(person, RustPerson, freedPerson);

  RustSlice name;

  CHECK_FFI(skylight_test_person_get_name(person, &name), "could not get person name");

  return SLICE2STR(name);
}

static VALUE person_get_age(VALUE self) {
  My_Struct(person, RustPerson, freedPerson);

  uint64_t age;

  CHECK_FFI(skylight_test_person_get_age(person, &age), "could not get person age");

  return ULL2NUM(age);
}

void Init_skylight_native_test() {
  rb_mSkylightTest = rb_define_module("SkylightTest");
  rb_mNumeric = rb_define_module_under(rb_mSkylightTest, "Numeric");
  rb_mStrings = rb_define_module_under(rb_mSkylightTest, "Strings");
  rb_mStructs = rb_define_module_under(rb_mSkylightTest, "Structs");
  rb_cPerson = rb_define_class_under(rb_mStructs, "Person", rb_cObject);
  
  rb_define_singleton_method(rb_mNumeric, "multiply", numeric_multiply, 2);

  rb_define_singleton_method(rb_mStrings, "reverse", strings_multiple, 1);

  rb_define_singleton_method(rb_cPerson, "new", person_new, 2);
  rb_define_method(rb_cPerson, "name", person_get_name, 0);
  rb_define_method(rb_cPerson, "age", person_get_age, 0);
}
