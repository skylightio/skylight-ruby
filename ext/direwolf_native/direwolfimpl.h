#ifndef __DIREWOLFIMPL_H__
#define __DIREWOLFIMPL_H__

#import "direwolf.h"
#import "stdint.h"
#import <string>
#import <vector>

/*
 *
 * ===== Portability =====
 *
 */
uint64_t current_time_nanos();


/***
 * Represents the world.
 *
 */
class Instrumenter {
};

class Span;

class Tracer {

  // Whether the tracer is valid
  bool _valid;

  // The root of the tree
  Span *_root;

  // The current node
  Span *_current;

  public:

    Tracer();
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
template <class T>
class UniformSample {

  /*
   * Sample size
   */
  int _size;

  /*
   * Number currently contained elements
   */
  int _count;

  /*
   * Array of values
   */
  T *_values;

  public:

    /*
     * Constructors and destructors
     */
    UniformSample(int s = 128);
    ~UniformSample();

    /*
     * returns the size of the sample
     */
    int size();
};

#endif
