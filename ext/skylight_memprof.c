#include <ruby.h>
#include <skylight_native.h>

#ifdef RUBY_INTERNAL_EVENT_NEWOBJ

typedef struct {
  uint64_t allocations;
} sky_allocations_t;

#ifdef HAVE_FAST_TLS

// Use the __thread directive
static __thread sky_allocations_t sky_allocations;

static inline sky_allocations_t* get_allocations() {
  return &sky_allocations;
}

#else

#include <pthread.h>

// Use pthread thread locals
static pthread_key_t ALLOCATIONS_KEY;

static pthread_once_t KEY_INIT_ONCE = PTHREAD_ONCE_INIT;

static void init_allocations_key() {
  pthread_key_create(&ALLOCATIONS_KEY, free);
}

static sky_allocations_t* get_allocations() {
  sky_allocations_t* ret;

  // Initialize the TLS key
  pthread_once(&KEY_INIT_ONCE, init_allocations_key);

  ret = (sky_allocations_t*) pthread_getspecific(ALLOCATIONS_KEY);

  if (ret == 0) {
    ret = (sky_allocations_t*) malloc(sizeof(sky_allocations_t));
    pthread_setspecific(ALLOCATIONS_KEY, (void*) ret);
  }

  return ret;
}

#endif

static void sky_increment_allocation(rb_event_flag_t flag, VALUE data, VALUE self, ID mid, VALUE klass) {
  UNUSED(flag);
  UNUSED(data);
  UNUSED(self);
  UNUSED(mid);
  UNUSED(klass);

  get_allocations()->allocations++;
}

void sky_activate_memprof(void) {
  rb_add_event_hook(sky_increment_allocation, RUBY_INTERNAL_EVENT_NEWOBJ, Qnil);
}

void sky_deactivate_memprof(void) {
  rb_remove_event_hook(sky_increment_allocation);
}

uint64_t sky_allocation_count(void) {
  return get_allocations()->allocations;
}

uint64_t sky_consume_allocations() {
  uint64_t ret = get_allocations()->allocations;
  sky_clear_allocation_count();
  return ret;
}

void sky_clear_allocation_count(void) {
  get_allocations()->allocations = 0;
}

int sky_have_memprof(void) {
  return 1;
}

#else
/*
 *
 * ===== No memory profiling ======
 *
 */

void sky_activate_memprof(void) {
}

void sky_deactivate_memprof(void) {
}

uint64_t sky_allocation_count(void) {
  return 0;
}

uint64_t sky_consume_allocations() {
  return 0;
}

void sky_clear_allocation_count(void) {
}

int sky_have_memprof(void) {
  return 0;
}


#endif
