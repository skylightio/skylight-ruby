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

dw_instrumenter_t
dw_instrumenter_init()
{
  return new Instrumenter();
}

int
dw_instrumenter_start(dw_instrumenter_t inst)
{
  inst->startWorker();
  return 0;
}

int
dw_instrumenter_shutdown(dw_instrumenter_t inst)
{
  // TODO: Implement
  return 0;
}

int
dw_instrumenter_destroy(dw_instrumenter_t instrumenter)
{
  delete instrumenter;
  return 0;
}
