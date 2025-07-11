//
//  RustCore/src/lib.rs
//  Storm Rust Core Logic
//
//  Provides high-performance ECS, AI, and procedural services.
//
//  Created by Wenyan Qin on 2025-07-09.
//

#[unsafe(no_mangle)]
pub extern "C" fn storm_hello() {
    println!("[🦀] Hello from Rust!");
}

#[repr(C)]
pub struct AgentSpec {
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub mood: u32,  // Enum: 0=neutral, 1=happy, 2=angry, 3=curious
}

#[unsafe(no_mangle)]
pub extern "C" fn storm_local_world_init(specs: *mut AgentSpec, max: usize) -> usize {
    if max < 1 {
        return 0;
    }
    unsafe {
        (*specs).x = 0.0;
        (*specs).y = 0.0;
        (*specs).z = 0.0;
        (*specs).mood = 1;  // happy
    }
    1
}