#ifndef __SKYLIGHT_NATIVE__
#define __SKYLIGHT_NATIVE__

#include <stdint.h>

void sky_activate_memprof(void);

void sky_deactivate_memprof(void);

uint64_t sky_allocation_count(void);

uint64_t sky_consume_allocations();

void sky_clear_allocation_count(void);

int sky_have_memprof(void);

#define UNUSED(x) (void)(x)

#endif
