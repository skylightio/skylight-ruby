#ifndef __DIREWOLF_H__
#define __DIREWOLF_H__

#ifdef __cplusplus
extern "C" {
#endif

#import <uuid/uuid.h>
#import <stddef.h>

/***
 *
 * ===== Defines =====
 *
 */

#define DW_REQUEST_ID_LENGTH 36

/***
 *
 * ===== Types =====
 *
 */

typedef struct Instrumenter* dw_instrumenter_t;
typedef struct Tracer* dw_tracer_t;
typedef uuid_t dw_request_id_t;

/*
 * Arguments to create a span
 */
typedef struct
{
  char *category;
  size_t category_len;
} dw_span_t;

/*
 *
 * ===== Configuration =====
 *
 */

dw_instrumenter_t dw_instrumenter_init();
int dw_instrumenter_destroy(dw_instrumenter_t instrumenter);

/*
 *
 * ===== Tracing =====
 *
 */

/*
 * Initialize a new tracer.
 */
dw_tracer_t dw_tracer_init();

/*
 * Destroy a tracer
 */
int dw_tracer_destroy(dw_tracer_t tracer);

/*
 * Record a single event.
 */
int dw_tracer_record(dw_tracer_t tracer, dw_span_t *span);

/*
 * Start recording a range
 */
int dw_tracer_record_range_start(dw_tracer_t tracer, dw_span_t *span);

/*
 * Finish recording the current range
 */
int dw_tracer_record_range_stop(dw_tracer_t tracer);


/*
 *
 * ===== Helpers =====
 *
 */

void dw_generate_request_id(dw_request_id_t out);
void dw_request_id_to_string(dw_request_id_t reqid, char *out);
void dw_request_id_from_string(char *in, dw_request_id_t reqid);

#ifdef __cplusplus
}
#endif

#endif
