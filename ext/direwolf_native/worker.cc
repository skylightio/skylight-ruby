#import "direwolfimpl.h"

Worker::Worker() :
  _th(NULL)
{}

void
Worker::start()
{
  int res = start_worker_thread(&_th, *this);

  if (!res)
    return;

  // TODO: add more detail
  throw Exception("somethign went wrong starting worker thread");
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
