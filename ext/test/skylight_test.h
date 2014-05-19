#ifndef __SKYLIGHT_TEST_H__
#define __SKYLIGHT_TEST_H__

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include <rust_support/ruby.h>

typedef void * RustPerson;

bool skylight_test_numeric_multiply(uint64_t, uint64_t, uint64_t*);
bool skylight_test_strings_reverse(RustSlice, RustString*);

bool skylight_test_person_new(RustSlice, uint64_t, RustPerson*);
bool skylight_test_person_get_name(RustPerson, RustSlice*);
bool skylight_test_person_get_age(RustPerson, uint64_t*);
bool skylight_test_person_free(RustPerson);

#endif
