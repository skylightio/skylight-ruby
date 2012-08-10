#import "direwolfimpl.h"

/*
 * Import the correct headers
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

  if (info.denom == 0) {
    // Should be safe to invoke this w/o any coordination. The result
    // should always be 1 o_O. But... it MIGHT change.
    mach_timebase_info(&info);
  }

  return mach_absolute_time() * info.numer / info.denom;
#else
  return 0;
#endif
}
