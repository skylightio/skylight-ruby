#ifndef __DIREWOLFIMPL_H__
#define __DIREWOLFIMPL_H__

#import "direwolf.h"
#import "stdint.h"
#import "stdlib.h"
#import <string>
#import <vector>

/*
 *
 * ===== Forward declarations ======
 *
 */

class Worker;

/*
 *
 * ===== Portability =====
 *
 */

// Return the current time in nanoseconds using a monotonic clock
uint64_t current_time_nanos();

// Worker thread state
typedef struct worker_thread_t* worker_thread_p;

// Start the worker thread
int start_worker_thread(worker_thread_p*, Worker &w);

// Cleans up the state.
int destroy_worker_thread(worker_thread_p*);

/*
 *
 * ===== Exceptions =====
 *
 */

// Base exception class
class Exception : public std::exception
{
  std::string msg;

  public:

    Exception(std::string m = "Something went wrong!") : msg(m) {}
    ~Exception() throw() {}
    const char *what() const throw() { return msg.c_str(); }
};

/*
 *
 * ===== Random number generator =====
 *
 */

class Random
{
  uint64_t rnd;

  public:

    Random(uint64_t s);

    uint32_t next32() { return next(32); }
    uint64_t next64();
    uint64_t next64(uint64_t n);

  private:

    uint32_t next(unsigned int bits);
};

class Worker
{
  worker_thread_p _th;

  public:

    Worker();

    // Called from the main thread to launch the worker
    void start();

    // Internal: called once the new thread has started running.
    void work();

};

/*
 *
 * Represents the world.
 *
 */
class Instrumenter
{
  Worker _worker;

  public:

    Instrumenter();

    void startWorker();
};

class Span;

class Trace
{
  // Whether the trace is valid
  bool _valid;

  // The root of the tree
  Span *_root;

  // The current node
  Span *_current;

  public:

    Trace();
    ~Trace();
    int record(dw_span_t *span);
    int start(dw_span_t *span);
    int stop();
};

#endif
