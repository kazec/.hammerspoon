//
//  connection.c
//  DS4IRC
//
//  Created by Fengwei Liu on 12/11/2017.
//  Copyright © 2017 Fengwei Liu. All rights reserved.
//

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <time.h>

#include "connection.h"

struct connection_t_ {
    // socket related
    int socket_fd;

    struct sockaddr_in server_addr;
    int server_port;

    uint8_t max_retries;
    uint8_t reconnect_seconds;
    time_t reconnect_timestamp;
};

connection_t *connection_open(const char *server_ip, uint16_t server_port, uint8_t max_retries, uint8_t reconnect_seconds) {
    int socket_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (!socket_fd) return NULL;

    in_addr_t addr = inet_addr(server_ip);
    if (addr == INADDR_NONE) return NULL;

    connection_t *connection = malloc(sizeof(connection_t));
    connection->socket_fd = socket_fd;
    connection->server_addr.sin_family = AF_INET;
    connection->server_addr.sin_addr.s_addr = addr;
    connection->server_addr.sin_port = htons(server_port);

    if (connect(socket_fd, (struct sockaddr *)&connection->server_addr, sizeof(struct sockaddr_in)) == -1) {
        close(socket_fd);
        free(connection);
        return NULL;
    }

    connection->max_retries = max_retries;
    connection->reconnect_seconds = reconnect_seconds;
    connection->reconnect_timestamp = -1;

    return connection;
}

void connection_send(connection_t *connection, const void* data, size_t data_len) {
    if (connection->reconnect_timestamp == -1) {
        for (uint8_t i = 0; i <= connection->max_retries; i++ ) {
            if (send(connection->socket_fd, data, data_len, 0) != -1) {
                return;
            }
        }
        // all retries failed, set the timestamp
        close(connection->socket_fd);
        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);
        connection->reconnect_timestamp = now.tv_sec;
    } else {
        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);

        if (now.tv_sec - connection->reconnect_timestamp >= connection->reconnect_seconds) {
            int socket_fd = socket(AF_INET, SOCK_DGRAM, 0);

            if (!connect(socket_fd, (struct sockaddr *)&connection->server_addr, sizeof(struct sockaddr_in))) {
                close(socket_fd);
                connection->reconnect_timestamp = now.tv_sec;

                // failed, wait for next reconnection
                return;
            } else {
                // successfully reconnected, resend
                connection->reconnect_timestamp = -1;
                connection_send(connection, data, data_len);
                return;
            }
        }
    }
}

void connection_close(connection_t *connection) {
    close(connection->socket_fd);
}
