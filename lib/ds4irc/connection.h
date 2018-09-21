//
//  connection.h
//  DS4IRC
//
//  Created by Fengwei Liu on 12/11/2017.
//  Copyright © 2017 Fengwei Liu. All rights reserved.
//

#ifndef connection_h
#define connection_h

#include <stdlib.h>

struct connection_t_;
typedef struct connection_t_ connection_t;

connection_t *connection_open(const char *server_ip, uint16_t server_port, uint8_t max_retries, uint8_t reconnect_seconds);
void connection_send(connection_t *connection, const void* data, size_t data_len);
void connection_close(connection_t *connection);

#endif /* connection_h */
