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

// Start the worker thread
void start_worker_thread(Worker &w);

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
  public:

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

/*
 *
 * Uniformly samples values using Vitter's Algorithm R to produce a
 * statistically representative sample.
 *
 */
class UniformSample
{
  /*
   * Sample size
   */
  int _size;

  /*
   * Number currently contained elements
   */
  int _count;

  // Traces
  std::vector<Trace*> _values;

  public:

    /*
     * Constructors and destructors
     */
    UniformSample(int s = 128);
    // ~UniformSample() {}

    /*
     * returns the size of the sample
     */
    int size() const { return _size; }

    /*
     * Updates the sample with a new trace
     */
    void update(Trace *t);
};

#endif
