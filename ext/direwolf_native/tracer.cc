#import "direwolf.h"
#import "direwolfimpl.h"

Tracer::Tracer() : _valid(true) {
}

int Tracer::record(const char *c, const char *desc) {
  if (!_valid)
    return 1;

  return 0;
}

int Tracer::start(const char *c, const char *desc) {
  if (!_valid)
    return 1;

  return 0;
}

int Tracer::stop() {
  if (!_valid)
    return 1;

  return 0;
}

/*
 *
 * ===== C API =====
 *
 */

dw_tracer_t dw_tracer_init() {
  return new Tracer();
}

int dw_tracer_destroy(dw_tracer_t tr) {
  delete tr;
  return 0;
}

int dw_tracer_record(dw_tracer_t tr, const char *c, const char *desc) {
  return tr->record(c, desc);
}

int dw_tracer_record_range_start(dw_tracer_t tr, const char *c, const char *desc) {
  return tr->start(c, desc);
}

int dw_tracer_record_range_stop(dw_tracer_t tr, const char *c, const char *desc) {
  return tr->stop();
}
