//
//  RustCore/storm.h
//  Storm
//
//  Bridge header for Rust → Swift interop
//

#ifndef STORM_BRIDGE_H
#define STORM_BRIDGE_H

void storm_hello(void);

typedef struct {
    float x;
    float y;
    float z;
    unsigned int mood;
} AgentSpec;

unsigned long storm_local_world_init(AgentSpec* specs, unsigned long max);

#endif