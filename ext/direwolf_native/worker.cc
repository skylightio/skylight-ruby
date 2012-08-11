#import "direwolfimpl.h"

void
Worker::start()
{
  start_worker_thread(*this);
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
