#import "direwolf.h"
#import "direwolfimpl.h"

using namespace std;

/*
 * Node in the current tier's trace
 *
 * TODO: Consider only having the last child point back to the parent.
 */
class Span
{
  // The elapsed time (in units of 0.1ms) since the previous sibling
  // event in the trace
  uint64_t _started_at;

  // The duration of the span (in units of 0.1ms)
  uint64_t _ended_at;

  // The category of the span
  string _category;

  // The Span's parent
  Span *_parent;

  // First span in the linked list of children
  Span *_first_child;
  Span *_last_child;

  // Next
  Span *_next;

  public:

    Span(Span *, const dw_span_t *);

    void push(Span *);

    friend class Trace;
};

Span::Span(Span *p, const dw_span_t *s) :
  _started_at(0),
  _ended_at(0),
  _category(s->category, s->category_len),
  _parent(p),
  _first_child(NULL),
  _last_child(NULL),
  _next(NULL)
{}

void
Span::push(Span *child)
{
  if (_last_child) {
    // If there is a last child, then we are appending the node to the
    // linked list
    _last_child->_next = child;
    _last_child = child;
  }
  else {
    _first_child = child;
    _last_child = child;
  }
}

Trace::Trace() :
  _valid(true),
  _root(NULL),
  _current(NULL)
{}

Trace::~Trace()
{
  Span *curr = _root, *tmp;

  while (curr) {
    if (curr->_first_child) {
      tmp  = curr;
      curr = curr->_first_child;

      tmp->_first_child = NULL;

      continue;
    }

    tmp  = curr;
    curr = curr->_next ? curr->_next : curr->_parent;

    delete tmp;
  }
}

void
Trace::release()
{
  delete this;
}

int
Trace::record(dw_span_t *s)
{
  Span *span;

  if (!_valid)
    return 1;

  if (!_current) {
    _valid = false;
    return 1;
  }

  span = new Span(_current, s);
  span->_started_at = current_time_nanos();

  // Push the node
  _current->push(span);

  return 0;
}

int
Trace::start(dw_span_t *s)
{
  Span *span;

  if (!_valid)
    return 1;

  span = new Span(_current, s);
  span->_started_at = current_time_nanos();

  if (_current) {
    _current->push(span);
    _current = span;
  }
  else {
    _root = span;
    _current = span;
  }

  return 0;
}

int
Trace::stop()
{
  if (!_valid)
    return 1;

  if (!_current) {
    _valid = false;
    return 1;
  }

  _current->_ended_at = current_time_nanos();
  _current = _current->_parent;

  return 0;
}

/*
 *
 * ===== C API =====
 *
 */

dw_trace_t
dw_trace_init()
{
  return new Trace();
}

int
dw_trace_destroy(dw_trace_t tr)
{
  tr->release();
  return 0;
}

int
dw_trace_record(dw_trace_t tr, dw_span_t *span)
{
  return tr->record(span);
}

int
dw_trace_record_range_start(dw_trace_t tr, dw_span_t *span)
{
  return tr->record(span);
}

int
dw_trace_record_range_stop(dw_trace_t tr)
{
  return tr->stop();
}
