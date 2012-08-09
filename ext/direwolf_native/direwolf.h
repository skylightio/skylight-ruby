#ifndef __DIREWOLF_H__
#define __DIREWOLF_H__

#import <uuid/uuid.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Some defines
 */
#define DW_REQUEST_ID_LENGTH 36

/*
 * Various types
 */
typedef uuid_t dw_request_id_t;

/*
 * Helper functions
 */

void dw_generate_request_id(dw_request_id_t out);
void dw_request_id_to_string(dw_request_id_t reqid, char *out);
void dw_request_id_from_string(char *in, dw_request_id_t reqid);

#ifdef __cplusplus
}
#endif

#endif
