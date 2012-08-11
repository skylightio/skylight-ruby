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
typedef struct Trace* dw_trace_t;
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
int dw_instrumenter_start(dw_instrumenter_t instrumenter);
int dw_instrumenter_shutdown(dw_instrumenter_t instrumenter);
int dw_instrumenter_destroy(dw_instrumenter_t instrumenter);

/*
 *
 * ===== Tracing =====
 *
 */

/*
 * Initialize a new trace.
 */
dw_trace_t dw_trace_init();

/*
 * Destroy a trace
 */
int dw_trace_destroy(dw_trace_t trace);

/*
 * Record a single event.
 */
int dw_trace_record(dw_trace_t trace, dw_span_t *span);

/*
 * Start recording a range
 */
int dw_trace_record_range_start(dw_trace_t trace, dw_span_t *span);

/*
 * Finish recording the current range
 */
int dw_trace_record_range_stop(dw_trace_t trace);


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
