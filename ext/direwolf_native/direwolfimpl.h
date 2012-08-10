#ifndef __DIREWOLFIMPL_H__
#define __DIREWOLFIMPL_H__

/***
 * Represents the world.
 *
 */
class Instrumenter {
};

class Tracer {

  // Whether the tracer is valid
  bool _valid;

  public:

    Tracer();
    int record(const char *c, const char *desc);
    int start(const char *c, const char *desc);
    int stop();
};

/***
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
