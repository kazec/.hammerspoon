//
//  main.c
//  DS4IRC
//
//  Created by Fengwei Liu on 12/11/2017.
//  Copyright © 2017 Fengwei Liu. All rights reserved.
//

#include <stdio.h>
#include <pthread.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/hid/IOHIDKeys.h>

#include <lua.h>
#include <lauxlib.h>

#include "ds4irc.h"
#include "connection.h"

typedef union {
    struct {
        uint8_t l3x_axis;  // L3 X Axis(Left(0x00) ~ Right(0xFF))
        uint8_t l3y_axis;  // L3 Y Axis(Up(0x00) ~ Down(0xFF))
        uint8_t r3x_axis;  // R3 X Axis
        uint8_t r3y_axis;  // R3 Y Axis
        uint8_t buttons1;  // Triangle/Circle/Cross/Square(0x80~0x10) & D-Pad(not bit-masked, see http://www.psdevwiki.com/ps4/DS4-USB)
        uint8_t buttons2;  // R3/L3 click & option/share & R2/L2 & R1/L1 (0x80~0x01)
        uint8_t buttons3;  // T-Pad active(0x04) & T-Pad click(0x02) & PS(0x01)
        uint8_t padding;
    } fields;

    uint64_t bits;
} state_t;

typedef struct {
    connection_t *connection;
    uint32_t commands[5];
    state_t prev_state;
} client_t;

static uint8_t calibrate(uint8_t axis) {
    return (axis >= 137 || axis <= 117) ? axis : 127; // insensitive when stick is almost centered
}

static void input_report_callback(void *context, IOReturn result, void *sender, IOHIDReportType report_type, uint32_t report_id, uint8_t *report,
                                  CFIndex report_length) {
    client_t *client = context;
    state_t s;
    s.bits = *((uint64_t *)(report + 1));
    s.fields.l3x_axis = calibrate(report[1]);
    s.fields.l3y_axis = calibrate(report[2]);
    s.fields.r3x_axis = calibrate(report[3]);
    s.fields.r3y_axis = calibrate(report[4]);
    s.fields.buttons1 = report[5];
    s.fields.buttons2 = report[6];
    s.fields.buttons3 = report[7] & 0x3;
    s.fields.padding = 0;

    if (report_length == 64) { // connected via USB
        if ((report[35] & 0x80) == 0) { // T-Pad finger down
            s.fields.buttons3 |= 0x04;
        } else if (client->prev_state.bits == s.bits) {
            return;
        }
    } else if (client->prev_state.bits == s.bits) {
        return;
    }

    client->prev_state = s;
    uint32_t command;

    // HID Buttons
    command = 0xfff;
    if (s.fields.buttons1 & 0x80) command ^= k3DSButtonX; // Triangle
    if (s.fields.buttons1 & 0x40) command ^= k3DSButtonA; // Circle
    if (s.fields.buttons1 & 0x20) command ^= k3DSButtonB; // Cross
    if (s.fields.buttons1 & 0x10) command ^= k3DSButtonY; // Square

    switch (s.fields.buttons1 & 0x0F) { // D-Pad
        case 0x08: break;
        case 0x00: command ^= k3DSButtonDPadUp;                         break;
        case 0x01: command ^= k3DSButtonDPadUp | k3DSButtonDPadRight;   break;
        case 0x02: command ^= k3DSButtonDPadRight;                      break;
        case 0x03: command ^= k3DSButtonDPadDown | k3DSButtonDPadRight; break;
        case 0x04: command ^= k3DSButtonDPadDown;                       break;
        case 0x05: command ^= k3DSButtonDPadUp | k3DSButtonDPadLeft;    break;
        case 0x06: command ^= k3DSButtonDPadLeft;                       break;
        case 0x07: command ^= k3DSButtonDPadUp | k3DSButtonDPadLeft;    break;
    }

    if (s.fields.buttons2 & 0x02) command ^= k3DSButtonR; // R1
    if (s.fields.buttons2 & 0x01) command ^= k3DSButtonL; // L1
    if (s.fields.buttons2 & 0x20) command ^= k3DSButtonStart; // OPTIONS
    if (s.fields.buttons2 & 0x10) command ^= k3DSButtonSelect; // SHARE

    client->commands[0] = command;

    // Touch Screen
    command = 0x02000000;
    if (report_length == 64) { // connected via USB
        if (s.fields.buttons3 & 0x04) { // T-Pad finger down
            float tx = ((report[37] & 0x0f) << 8) | report[36];
            float ty = report[38] << 4 | ((report[37] & 0xf0) >> 4);
            uint16_t x = 0xfff * tx / 1920;
            uint16_t y = 0xfff * ty / 943;
            command = (1 << 24) | (y << 12) | x;
        }
    } else if (s.fields.buttons3 & 0x02) { // connected via Bluetooth, T-Pad clicked
        command = (1 << 24) | ((0xFFF * (5 / k3DSTouchScreenHeight)) << 12) | (0xFFF * (315 / k3DSTouchScreenHeight));
    }

    client->commands[1] = command;

    // C-Pad
    // command = 0x007ff7ff;
    uint16_t x = s.fields.l3x_axis << 4 | s.fields.l3x_axis >> 4;
    uint16_t y = 0xFFF - (s.fields.l3y_axis << 4 | s.fields.l3y_axis >> 4);
    client->commands[2] = x | (y << 12);

    // C-Stick & ZL/ZR
    // command = 0x80800081;
    uint8_t zlzr = 0x00;
    if (s.fields.buttons2 & 0x08) zlzr |= kN3DSButtonZR; // R2
    if (s.fields.buttons2 & 0x04) zlzr |= kN3DSButtonZL; // L2

    // rotate 45° + 180°
    float fx = 0x80 - M_SQRT1_2 * (s.fields.r3x_axis + s.fields.r3y_axis - 0xFF);
    float fy = 0x80 - M_SQRT1_2 * (s.fields.r3y_axis - s.fields.r3x_axis);
    x  = fx > 0xFF ? 0xFF : (fx < 0 ? 0 : fx);
    y  = fy > 0xFF ? 0xFF : (fy < 0 ? 0 : fy);

    client->commands[3] = (x << 24) | (y << 16) | zlzr << 8 | 0x81;

    // Special Buttons
    command = 0x00000000;
    if (s.fields.buttons3 & 0x01) command |= k3DSHome; // PS button
    // if (s.fields.buttons2 & 0x80) command |= k3DSPower; // R3
    // if (s.fields.buttons2 & 0x40) command |= k3DSPowerLong; // L3
    client->commands[4] = command;

    connection_send(client->connection, client->commands, 20);
}

static void removal_callback(void *refcon, io_service_t service, uint32_t messageType, void *messageArgument) {
    if (messageType == kIOMessageServiceIsTerminated) {
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
}

static closed = true;
static pthread_t thread = 0;
static CFRunLoopRef run_loop = NULL;

static void* start(void *context) {
    // create the client struct
    client_t client;
    client.connection = (connection_t *)context;
    client.prev_state.bits = 0x000000087F7F7F7F;

    /// connect to Dualshocks 4

    IOReturn result;
    CFMutableDictionaryRef matching;
    io_service_t service;
    IOCFPlugInInterface **plugin_interface;
    IOHIDDeviceDeviceInterface ** device_interface;
    uint8_t *input_report_buffer;
    CFTypeRef async_event_source;
    io_object_t notification;
    IONotificationPortRef notification_port;

    // create matching dictionary
    matching = IOServiceMatching(kIOHIDDeviceKey);

    int vid = 1356, pid = 1476;
    CFNumberRef vidRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &vid);
    CFNumberRef pidRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &pid);
    CFDictionarySetValue(matching, CFSTR(kIOHIDVendorIDKey), vidRef);
    CFDictionarySetValue(matching, CFSTR(kIOHIDProductIDKey), pidRef);

    // get matching service
    service = IOServiceGetMatchingService(kIOMasterPortDefault, matching);
    if (!service) goto error;

    // get plugin interface
    SInt32 score;
    result = IOCreatePlugInInterfaceForService(service,
                                               kIOHIDDeviceTypeID,
                                               kIOCFPlugInInterfaceID,
                                               &plugin_interface,
                                               &score);
    if (result != kIOReturnSuccess) goto plugin_error;

    // get device interface
    result = (*plugin_interface)->QueryInterface(plugin_interface,
                                                 CFUUIDGetUUIDBytes(kIOHIDDeviceDeviceInterfaceID),
                                                 (LPVOID)&device_interface);
    if (result != kIOReturnSuccess) goto query_error;

    // configure device interface
    input_report_buffer = malloc(64);
    result = (*device_interface)->setInputReportCallback(device_interface,
                                                         input_report_buffer,
                                                         64,
                                                         input_report_callback,
                                                         &client,
                                                         0);
    if (result != kIOReturnSuccess) goto config_error;

    result = (*device_interface)->getAsyncEventSource(device_interface, &async_event_source);
    if (result != kIOReturnSuccess) goto config_error;

    result = (*device_interface)->open(device_interface, kIOHIDOptionsTypeSeizeDevice);
    if (result != kIOReturnSuccess) goto config_error;

    // configure removal notification
    notification_port = IONotificationPortCreate(kIOMasterPortDefault);
    if (!notification_port) goto config_error;

    result = IOServiceAddInterestNotification(notification_port,
                                              service,
                                              kIOGeneralInterest,
                                              removal_callback,
                                              NULL,
                                              &notification);
    if (result != kIOReturnSuccess) goto notify_error;

    // run the run loop until device is removed
    run_loop = CFRunLoopGetCurrent();
    CFStringRef run_loop_mode = CFSTR("DS4IRC_RUNLOOP_MODE");
    CFRunLoopAddSource(run_loop, (CFRunLoopSourceRef)async_event_source, run_loop_mode);
    CFRunLoopAddSource(run_loop, IONotificationPortGetRunLoopSource(notification_port), run_loop_mode);
    CFRunLoopRunInMode(run_loop_mode, 1.0e10, FALSE);

    // exit when device is removed
    IOObjectRelease(notification);

notify_error:
    IONotificationPortDestroy(notification_port);
config_error:
    free(input_report_buffer);
query_error:
    IODestroyPlugInInterface(plugin_interface);
plugin_error:
    IOObjectRelease(service);
error:
    connection_close(client.connection);
    closed = true;
    return NULL;
}

static int ds4irc_stop(lua_State *L) {
  if (closed) return 0;

  CFRunLoopStop(run_loop);
  if (pthread_join(thread, NULL) != 0) {
    return luaL_error(L, "Failed to stop ds4irc thread.\n");
  }

  return 0;
}

static int ds4irc_start(lua_State *L) {
    if (!closed) {
      if (lua_toboolean(L, 1)) { // force restart
        ds4irc_stop(L);
      } else {
        return luaL_error(L, "Previous ds4irc session not closed.\n");
      }
    }

    const char *server_ip = luaL_checkstring(L, 1);
    uint16_t server_port = luaL_checkinteger(L, 2);
    // connect to 3ds input redirection server
    connection_t *connection = connection_open(server_ip, server_port, 5, 2);
    if (!connection) {
        return luaL_error(L, "Failed to connect to 3DS at (%s:%d).\n", server_ip, server_port);
    }

    closed = false;
    pthread_create(&thread, NULL, start, connection);

    usleep(1000);
    if (closed) {
      return luaL_error(L, "Failed to start ds4irc thread.\n");
    }

    return 0;
}

int luaopen_ds4irc(lua_State *L) {
    lua_newtable(L);
    lua_pushcfunction(L, ds4irc_start); lua_setfield(L, -2, "start");
    lua_pushcfunction(L, ds4irc_stop); lua_setfield(L, -2, "stop");
    return 1;
}
