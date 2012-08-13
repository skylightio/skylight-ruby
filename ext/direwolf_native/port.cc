#import "direwolfimpl.h"

/*
 *
 * ===== Timer =====
 *
 */

#if __APPLE__
#include <mach/mach_time.h>
#endif

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

/*
 *
 * ===== Threading =====
 *
 */

#include "pthread.h"

struct worker_thread_t
{
  pthread_t thread_id;
};

void
init_worker_thread(worker_thread_t** thp)
{
  worker_thread_t* th;
 
  th = (worker_thread_t*) malloc(sizeof(worker_thread_t));
  th->thread_id = NULL;

  *thp = th;
}

extern "C" void*
handle_start_worker_thread(void* arg)
{
  Worker* w = static_cast<Worker*>(arg);
  w->work();
  pthread_exit(NULL);
}

// TODO: Consider locking
void
start_worker_thread(worker_thread_t** thp, Worker &w)
{
  worker_thread_t* th;
  pthread_attr_t attr;

  // struct not initialized
  if (!*thp)
    throw Exception("worker thread struct not initialized");

  th = *thp;

  pthread_attr_init(&attr);
  pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);

  // Create the thread
  if (0 != pthread_create(&(th->thread_id), &attr, handle_start_worker_thread, (void*) &w))
    throw Exception("could not create worker thread");

  // Cleanup the attributes
  pthread_attr_destroy(&attr);
}

void
destroy_worker_thread(worker_thread_t** thp)
{
  // Return if the pointer is NULL
  if (!*thp)
    return;

  // Join the worker thread

  // Cleanup
  free(*thp);
}
