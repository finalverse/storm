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