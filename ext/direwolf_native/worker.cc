#import "direwolfimpl.h"

Worker::Worker() :
  _th(NULL)
{
  init_worker_thread(&_th);
}

void
Worker::start()
{
  start_worker_thread(&_th, *this);
}

void
Worker::shutdown()
{
  destroy_worker_thread(&_th);
  _th = NULL;
}

void
Worker::work()
{
  Random r(current_time_nanos());

  printf("ZOMG! I am working!!! Let's see some random numbers\n");

  unsigned int c = 0;

  while (r.next32() > 100000)
    ++c;

  printf("COUNT: %u\n", c);
}
