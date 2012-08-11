#import "direwolf.h"
#import "direwolfimpl.h"

Instrumenter::Instrumenter() :
  _worker()
{}

inline void
Instrumenter::startWorker()
{
  _worker.start();
}

dw_instrumenter_t dw_instrumenter_init() {
  Instrumenter *i = new Instrumenter();

  // Launch the worker thread
  i->startWorker();

  return i;
}

int dw_instrumenter_destroy(dw_instrumenter_t instrumenter) {
  delete instrumenter;
  return 0;
}
