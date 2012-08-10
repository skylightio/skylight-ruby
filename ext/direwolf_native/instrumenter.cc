#import "direwolf.h"
#import "direwolfimpl.h"

dw_instrumenter_t dw_instrumenter_init() {
  return new Instrumenter();
}

int dw_instrumenter_destroy(dw_instrumenter_t instrumenter) {
  delete instrumenter;
  return 0;
}
