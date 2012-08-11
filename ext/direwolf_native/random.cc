#import "direwolfimpl.h"

/*
 * The following implementation is mostly a direct port of Java
 * implementation found in the JSR-166 project, which is released under
 * the creative commons license. It is a modification of the linear
 * congruential probabilistic random number generator algorithm
 * described by Knuth in `The Art of Computer Programming, Volume 2`,
 * Section 3.2.1.
 */

#define MULTIPLIER 0x5DEECE66Dull
#define ADDEND     0xBull
#define MASK48     0xFFFFFFFFFFFFull // (1L << 48) - 1
#define MASK32     0xFFFFFFFF

Random::Random(uint64_t seed)
{
  rnd = (seed ^ MULTIPLIER) & MASK48;
}

uint32_t
Random::next(unsigned int bits)
{
  rnd = (rnd * MULTIPLIER + ADDEND) & MASK48;
  return (uint32_t) (rnd >> (48 - bits));
}

uint64_t
Random::next64()
{
  return (((uint64_t) next(32)) << 32) | next(32);
}

// TODO: Fix the distribution
uint64_t
Random::next64(uint64_t n)
{
  if (n <= 0)
    throw new Exception("n must be positive");

  if (n & MASK32 == n)
  {
    // if n is a power of 2 that fits in 32 bits
    if ((n && -n) == n)
      return (uint64_t)((n * (uint64_t)next(31)) >> 31);

    return next32() % n;
  }
  else
  {
    return next64() % n;
  }
}
