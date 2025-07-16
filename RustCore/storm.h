//
// RustCore/storm.h
// Storm RustCore C Interface
//
// Comprehensive C header providing FFI interface for Swift integration
// with AI-native virtual world engine capabilities.
//

#ifndef STORM_CORE_H
#define STORM_CORE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// Core Type Definitions
// ============================================================================

/// Opaque handle for Storm runtime instance
typedef struct StormRuntimeHandle StormRuntimeHandle;

/// Event priority levels
typedef enum {
    STORM_PRIORITY_SYSTEM = 0,
    STORM_PRIORITY_REALTIME = 1,
    STORM_PRIORITY_AI = 2,
    STORM_PRIORITY_NETWORK = 3,
    STORM_PRIORITY_BACKGROUND = 4
} StormEventPriority;

/// AI enhancement levels
typedef enum {
    STORM_AI_NONE = 0,
    STORM_AI_BASIC = 1,
    STORM_AI_ENHANCED = 2,
    STORM_AI_PREDICTIVE = 3,
    STORM_AI_ADAPTIVE = 4
} StormAIEnhancementLevel;

/// Core event structure
typedef struct {
    uint64_t event_id;
    uint32_t event_type;
    uint8_t priority;
    uint8_t ai_enhancement_level;
    uint64_t timestamp;
    uint32_t source_component;
    uint32_t target_component;
    size_t data_size;
    float ai_confidence;
    uint32_t processing_flags;
} StormEvent;

/// Resource requirements structure
typedef struct {
    uint8_t cpu_intensity;      // 0-255 scale
    uint32_t memory_usage;      // Estimated bytes
    bool gpu_required;          // GPU acceleration needed
    uint32_t network_bandwidth; // Required bandwidth
} StormResourceRequirements;

/// AI metadata structure
typedef struct {
    float confidence_score;
    uint8_t complexity_rating;
    uint32_t processing_time_estimate;
    StormResourceRequirements resource_requirements;
} StormAIMetadata;

// ============================================================================
// Result Codes
// ============================================================================

#define STORM_SUCCESS                    0
#define STORM_ERROR_INVALID_PARAMETERS   1
#define STORM_ERROR_INITIALIZATION_FAILED 2
#define STORM_ERROR_OUT_OF_MEMORY        3
#define STORM_ERROR_AI_PROCESSING_FAILED 4
#define STORM_ERROR_PROTOCOL_ERROR       5
#define STORM_ERROR_STATE_CONFLICT       6
#define STORM_ERROR_NETWORK_ERROR        7

// ============================================================================
// Event Type Constants
// ============================================================================

#define STORM_EVENT_STATE_CHANGE         1
#define STORM_EVENT_RENDER_FRAME         2
#define STORM_EVENT_USER_INPUT           3
#define STORM_EVENT_NETWORK_MESSAGE      4
#define STORM_EVENT_AI_ANALYSIS          5
#define STORM_EVENT_PROTOCOL_UPDATE      6
#define STORM_EVENT_PERFORMANCE_WARNING  7

// ============================================================================
// Component ID Constants
// ============================================================================

#define STORM_COMPONENT_STATE_MANAGER    1
#define STORM_COMPONENT_EVENT_BUS        2
#define STORM_COMPONENT_AI_ORCHESTRATOR  3
#define STORM_COMPONENT_RENDER_ENGINE    4
#define STORM_COMPONENT_INPUT_CONTROLLER 5
#define STORM_COMPONENT_NETWORK_MANAGER  6
#define STORM_COMPONENT_BROADCAST        0xFFFFFFFF

// ============================================================================
// Core Runtime Functions
// ============================================================================

/// Create new Storm runtime instance with AI capabilities
/// Returns: Pointer to runtime handle or NULL on failure
StormRuntimeHandle* storm_runtime_create(void);

/// Initialize Storm runtime with JSON configuration
/// Parameters:
///   - handle: Runtime handle from storm_runtime_create()
///   - config_json: JSON configuration string
/// Returns: STORM_SUCCESS or error code
uint32_t storm_runtime_initialize(StormRuntimeHandle* handle, 
                                  const char* config_json);

/// Process single frame with AI enhancement
/// Parameters:
///   - handle: Runtime handle
///   - delta_time: Time since last frame in seconds
/// Returns: STORM_SUCCESS or error code
uint32_t storm_runtime_tick(StormRuntimeHandle* handle, 
                           float delta_time);

/// Publish event to Storm runtime
/// Parameters:
///   - handle: Runtime handle
///   - event: Event structure
///   - data: Event payload data
///   - data_len: Length of payload data
/// Returns: Event ID or 0 on failure
uint64_t storm_runtime_publish_event(StormRuntimeHandle* handle,
                                     const StormEvent* event,
                                     const uint8_t* data,
                                     size_t data_len);

/// Subscribe to events with filter
/// Parameters:
///   - handle: Runtime handle
///   - component_id: Subscribing component ID
///   - event_types: Array of event types to subscribe to
///   - type_count: Number of event types
/// Returns: Subscription handle or 0 on failure
uint64_t storm_runtime_subscribe(StormRuntimeHandle* handle,
                                uint32_t component_id,
                                const uint32_t* event_types,
                                size_t type_count);

/// Unsubscribe from events
/// Parameters:
///   - handle: Runtime handle
///   - subscription_handle: Handle from storm_runtime_subscribe()
/// Returns: STORM_SUCCESS or error code
uint32_t storm_runtime_unsubscribe(StormRuntimeHandle* handle,
                                  uint64_t subscription_handle);

/// Destroy Storm runtime instance
/// Parameters:
///   - handle: Runtime handle to destroy
void storm_runtime_destroy(StormRuntimeHandle* handle);

// ============================================================================
// State Management Functions
// ============================================================================

/// Update state with AI-driven conflict resolution
/// Parameters:
///   - handle: Runtime handle
///   - path: State path (e.g., "/world/objects/123/position")
///   - data: State data
///   - data_len: Length of state data
///   - source_protocol: Optional source protocol name
/// Returns: STORM_SUCCESS or error code
uint32_t storm_state_update(StormRuntimeHandle* handle,
                           const char* path,
                           const uint8_t* data,
                           size_t data_len,
                           const char* source_protocol);

/// Retrieve state with intelligent caching
/// Parameters:
///   - handle: Runtime handle
///   - path: State path
///   - data_out: Output buffer for state data
///   - max_len: Maximum length of output buffer
///   - actual_len: Actual length of retrieved data
/// Returns: STORM_SUCCESS or error code
uint32_t storm_state_get(StormRuntimeHandle* handle,
                        const char* path,
                        uint8_t* data_out,
                        size_t max_len,
                        size_t* actual_len);

/// Synchronize state across protocols
/// Parameters:
///   - handle: Runtime handle
/// Returns: STORM_SUCCESS or error code
uint32_t storm_state_synchronize(StormRuntimeHandle* handle);

// ============================================================================
// AI Orchestration Functions
// ============================================================================

/// Get AI analysis of current system state
/// Parameters:
///   - handle: Runtime handle
///   - analysis_type: Type of analysis requested
///   - result_buffer: Buffer for analysis results
///   - buffer_len: Length of result buffer
/// Returns: STORM_SUCCESS or error code
uint32_t storm_ai_analyze_system(StormRuntimeHandle* handle,
                                uint32_t analysis_type,
                                char* result_buffer,
                                size_t buffer_len);

/// Configure AI enhancement parameters
/// Parameters:
///   - handle: Runtime handle
///   - component_id: Component to configure
///   - enhancement_level: AI enhancement level
///   - config_json: JSON configuration
/// Returns: STORM_SUCCESS or error code
uint32_t storm_ai_configure_enhancement(StormRuntimeHandle* handle,
                                       uint32_t component_id,
                                       StormAIEnhancementLevel enhancement_level,
                                       const char* config_json);

/// Get AI performance metrics
/// Parameters:
///   - handle: Runtime handle
///   - metrics_buffer: Buffer for metrics JSON
///   - buffer_len: Length of metrics buffer
/// Returns: STORM_SUCCESS or error code
uint32_t storm_ai_get_metrics(StormRuntimeHandle* handle,
                             char* metrics_buffer,
                             size_t buffer_len);

// ============================================================================
// Protocol Bridge Functions
// ============================================================================

/// Register protocol bridge for universal compatibility
/// Parameters:
///   - handle: Runtime handle
///   - protocol_name: Name of the protocol
///   - bridge_config: JSON configuration for the bridge
/// Returns: STORM_SUCCESS or error code
uint32_t storm_protocol_register_bridge(StormRuntimeHandle* handle,
                                        const char* protocol_name,
                                        const char* bridge_config);

/// Send message through protocol bridge
/// Parameters:
///   - handle: Runtime handle
///   - protocol_name: Target protocol
///   - message_data: Message payload
///   - data_len: Length of message payload
/// Returns: STORM_SUCCESS or error code
uint32_t storm_protocol_send_message(StormRuntimeHandle* handle,
                                     const char* protocol_name,
                                     const uint8_t* message_data,
                                     size_t data_len);

/// Get protocol status and statistics
/// Parameters:
///   - handle: Runtime handle
///   - protocol_name: Protocol to query
///   - status_buffer: Buffer for status JSON
///   - buffer_len: Length of status buffer
/// Returns: STORM_SUCCESS or error code
uint32_t storm_protocol_get_status(StormRuntimeHandle* handle,
                                  const char* protocol_name,
                                  char* status_buffer,
                                  size_t buffer_len);

// ============================================================================
// Performance and Monitoring Functions
// ============================================================================

/// Get runtime performance metrics
/// Parameters:
///   - handle: Runtime handle
///   - metrics: Output structure for metrics
/// Returns: STORM_SUCCESS or error code
typedef struct {
    float frame_time_ms;
    float cpu_usage_percent;
    uint64_t memory_usage_bytes;
    uint32_t active_events;
    uint32_t ai_tasks_queued;
    float ai_processing_efficiency;
} StormPerformanceMetrics;

uint32_t storm_runtime_get_performance(StormRuntimeHandle* handle,
                                      StormPerformanceMetrics* metrics);

/// Configure performance optimization parameters
/// Parameters:
///   - handle: Runtime handle
///   - config_json: JSON configuration for optimization
/// Returns: STORM_SUCCESS or error code
uint32_t storm_runtime_configure_optimization(StormRuntimeHandle* handle,
                                              const char* config_json);

// ============================================================================
// Utility Functions
// ============================================================================

/// Get last error message
/// Returns: Null-terminated error string
const char* storm_get_last_error(void);

/// Get version information
/// Returns: Null-terminated version string
const char* storm_get_version(void);

/// Check if feature is available
/// Parameters:
///   - feature_name: Name of feature to check
/// Returns: true if available, false otherwise
bool storm_feature_available(const char* feature_name);

// ============================================================================
// Callback Definitions
// ============================================================================

/// Event callback function type
/// Parameters:
///   - event: Event that occurred
///   - data: Event payload data
///   - data_len: Length of payload data
///   - user_data: User-provided context data
typedef void (*StormEventCallback)(const StormEvent* event,
                                  const uint8_t* data,
                                  size_t data_len,
                                  void* user_data);

/// Register event callback
/// Parameters:
///   - handle: Runtime handle
///   - callback: Callback function
///   - user_data: User context data
/// Returns: Callback handle or 0 on failure
uint64_t storm_runtime_register_callback(StormRuntimeHandle* handle,
                                         StormEventCallback callback,
                                         void* user_data);

/// Unregister event callback
/// Parameters:
///   - handle: Runtime handle
///   - callback_handle: Handle from storm_runtime_register_callback()
/// Returns: STORM_SUCCESS or error code
uint32_t storm_runtime_unregister_callback(StormRuntimeHandle* handle,
                                           uint64_t callback_handle);

#ifdef __cplusplus
}
#endif

#endif // STORM_CORE_H