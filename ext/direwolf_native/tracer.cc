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

  // The category of the span
  string _category;

  // The Span's parent
  Span *_parent;

  // First span in the linked list of children
  Span *_first_child;
  Span *_last_child;

  // Next sibling
  Span *_next_sibling;

  public:

    Span(Span *, const dw_span_t *);
    ~Span();

    // Accessors
    Span *parent();

    void push(Span *);
};

Span::Span(Span *p, const dw_span_t *s) :
  _category(s->category, s->category_len),
  _parent(p),
  _first_child(NULL),
  _last_child(NULL),
  _next_sibling(NULL)
{}

Span::~Span()
{}

void
Span::push(Span *child)
{
  if (_last_child) {
    // If there is a last child, then we are appending the node to the
    // linked list
    _last_child->_next_sibling = child;
    _last_child = child;
  }
  else {
    _first_child = child;
    _last_child = child;
  }
}

Span *
Span::parent()
{
  return _parent;
}

Tracer::Tracer() :
  _valid(true),
  _root(NULL),
  _current(NULL)
{
}

int
Tracer::record(dw_span_t *s)
{
  if (!_valid)
    return 1;

  if (!_current) {
    _valid = false;
    return 1;
  }

  // Push the node
  _current->push(new Span(_current, s));

  return 0;
}

int
Tracer::start(dw_span_t *s)
{
  if (!_valid)
    return 1;

  Span *span = new Span(_current, s);

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
Tracer::stop()
{
  if (!_valid)
    return 1;

  if (!_current) {
    _valid = false;
    return 1;
  }

  _current = _current->parent();

  return 0;
}

/*
 *
 * ===== C API =====
 *
 */

dw_tracer_t
dw_tracer_init()
{
  return new Tracer();
}

int
dw_tracer_destroy(dw_tracer_t tr)
{
  delete tr;
  return 0;
}

int
dw_tracer_record(dw_tracer_t tr, dw_span_t *span)
{
  return tr->record(span);
}

int
dw_tracer_record_range_start(dw_tracer_t tr, dw_span_t *span)
{
  return tr->record(span);
}

int
dw_tracer_record_range_stop(dw_tracer_t tr)
{
  return tr->stop();
}
