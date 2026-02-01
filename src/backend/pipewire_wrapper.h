#ifndef __PIPEWIRE_WRAPPER_H__
#define __PIPEWIRE_WRAPPER_H__

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct pw_core;
struct pw_thread_loop;

int gpw_create_link(struct pw_core *core,
                    uint32_t output_node_id,
                    uint32_t output_port_id,
                    uint32_t input_node_id,
                    uint32_t input_port_id);

int gpw_sync_core(struct pw_core *core, struct pw_thread_loop *loop, int seq);

void gpw_registry_destroy(struct pw_registry *registry);

#ifdef __cplusplus
}
#endif

#endif /* __PIPEWIRE_WRAPPER_H__ */

void gpw_core_add_listener(struct pw_core *core,
                           struct spa_hook *listener,
                           const struct pw_core_events *events,
                           void *data);

void gpw_registry_add_listener(struct pw_registry *registry,
                               struct spa_hook *listener,
                               const struct pw_registry_events *events,
                               void *data);
