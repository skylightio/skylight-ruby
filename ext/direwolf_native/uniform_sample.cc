#import "direwolf.h"
#import "direwolfimpl.h"

template <class T>
UniformSample<T>::UniformSample(int s) {
  _size   = s;
  _count  = 0;
  _values = new T[s];
}

template <class T>
UniformSample<T>::~UniformSample() {
  delete _values;
}

template <class T>
int UniformSample<T>::size() {
  return _size;
}
