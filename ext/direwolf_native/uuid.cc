#import <stdio.h>
#import "direwolf.h"

void dw_generate_request_id(dw_request_id_t out) {
  uuid_generate(out);
}

void dw_request_id_to_string(dw_request_id_t reqid, char *out) {
  uuid_unparse(reqid, out);
}

void dw_request_id_from_string(char *in, dw_request_id_t reqid) {
  uuid_parse(in, reqid);
}
