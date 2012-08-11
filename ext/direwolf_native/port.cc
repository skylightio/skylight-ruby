#import "direwolfimpl.h"

#if __APPLE__
#include <mach/mach_time.h>
#endif

#include "pthread.h"

uint64_t
current_time_nanos()
{
#if __APPLE__
  uint64_t time;

  // Man, this is stupid, consider just deleting it all since
  // mach_absolute_time() is in nanos and probably will never change.
  static mach_timebase_info_data_t info;

  if (info.denom == 0)
  {
    // Should be safe to invoke this w/o any coordination. The result
    // should always be 1 o_O. But... it MIGHT change.
    mach_timebase_info(&info);
  }

  return mach_absolute_time() * info.numer / info.denom;
#else
  return 0;
#endif
}

extern "C" void *
handle_start_worker_thread(void *arg)
{
  Worker *w = static_cast<Worker*>(arg);
  w->work();
  pthread_exit(NULL);
}


void
start_worker_thread(Worker &w)
{
  pthread_t thread;
  pthread_attr_t attr;

  pthread_attr_init(&attr);
  pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);

  // Create the thread
  if (0 != pthread_create(&thread, &attr, handle_start_worker_thread, &w))
    throw Exception("could not create worker thread");

  // Cleanup the attributes
  pthread_attr_destroy(&attr);
}
