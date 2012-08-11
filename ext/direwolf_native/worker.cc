#import "direwolfimpl.h"

void
Worker::start()
{
  start_worker_thread(*this);
}

void
Worker::work()
{
  printf("ZOMG! I am working!!!\n");
}
