#ifndef __RUST_H__
#define __RUST_H__

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

/**
 * Rust types
 */

typedef struct {
  char* data;
  long len;
} RustSlice;

typedef void* RustVec;
typedef void* RustString;

bool rust_string_as_slice(RustString, RustSlice*);

#define TO_S(VAL) \
  RSTRING_PTR(rb_funcall(VAL, rb_intern("to_s"), 0))

#define CHECK_NUMERIC(VAL)                        \
  do {                                            \
    if (TYPE(VAL) != T_BIGNUM &&                  \
        TYPE(VAL) != T_FIXNUM) {                  \
      rb_raise(rb_eArgError, "expected " #VAL " to be numeric but was '%s' (%s [%i])", \
                TO_S(VAL), rb_obj_classname(VAL), TYPE(VAL)); \
      return Qnil;                                \
    }                                             \
  } while(0)                                      \

#define CHECK_TYPE(VAL, T)                        \
  do {                                            \
    if (TYPE(VAL) != T) {                         \
      rb_raise(rb_eArgError, "expected " #VAL " to be " #T " but was '%s' (%s [%i])", \
                TO_S(VAL), rb_obj_classname(VAL), TYPE(VAL)); \
      return Qnil;                                \
    }                                             \
  } while(0)                                      \

#define CHECK_FFI(success, message)               \
  ({                                              \
    if (!(success))                               \
      rb_raise(rb_eRuntimeError, message);        \
  })

#define SLICE2STR(slice)                        \
  ({                                            \
    RustSlice s = (slice);                      \
    VALUE str = rb_str_new(s.data, s.len);      \
    rb_enc_associate(str, rb_utf8_encoding());  \
    str;                                        \
  })

#define STR2SLICE(string)         \
  ({                              \
    RustSlice s;                  \
    VALUE rb_str = (string);      \
    s.data = RSTRING_PTR(rb_str); \
    s.len = RSTRING_LEN(rb_str);  \
    s;                            \
  })

#define RUSTSTR2STR(string)          \
  ({                                 \
    RustString s = (string);         \
    RustSlice slice;                  \
    CHECK_FFI(rust_string_as_slice(s, &slice), "Couldn't convert String to &str"); \
    SLICE2STR(slice);                    \
  })

#endif

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
  }
