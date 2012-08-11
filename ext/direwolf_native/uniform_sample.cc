#import "direwolf.h"
#import "direwolfimpl.h"

UniformSample::UniformSample(int s) :
  _values(s),
  _size(s),
  _count(0)
{}

void
UniformSample::update(Trace *t)
{
  // If capacity has not been reached yet, then just track the trace
  if (_size >= ++_count)
  {
    _values[_count - 1] = t;
  }
  else
  {
  }
}
