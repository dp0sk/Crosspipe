
#include <pipewire/pipewire.h>
#include <spa/utils/dict.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/** 
 * @param core PipeWire core
 * @param output_node_id Output node ID
 * @param output_port_id Output port ID
 * @param input_node_id Input node ID
 * @param input_port_id Input port ID
 * @return 0 on success, negative error code on failure
 */
int gpw_create_link(struct pw_core *core,
                    uint32_t output_node_id,
                    uint32_t output_port_id,
                    uint32_t input_node_id,
                    uint32_t input_port_id)
{
    if (core == NULL) {
        return -EINVAL;
    }
    
    char val[4][16];
    snprintf(val[0], sizeof(val[0]), "%u", output_node_id);
    snprintf(val[1], sizeof(val[1]), "%u", output_port_id);
    snprintf(val[2], sizeof(val[2]), "%u", input_node_id);
    snprintf(val[3], sizeof(val[3]), "%u", input_port_id);
    
    struct spa_dict_item items[6];
    uint32_t n_items = 0;
    
    items[n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_LINK_OUTPUT_NODE, val[0]);
    items[n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_LINK_OUTPUT_PORT, val[1]);
    items[n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_LINK_INPUT_NODE, val[2]);
    items[n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_LINK_INPUT_PORT, val[3]);
    items[n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_OBJECT_LINGER, "true");
    
    const char *str = getenv("PIPEWIRE_LINK_PASSIVE");
    if (str && pw_properties_parse_bool(str)) {
        items[n_items++] = SPA_DICT_ITEM_INIT(PW_KEY_LINK_PASSIVE, "true");
    }
    
    struct spa_dict props = SPA_DICT_INIT(items, n_items);
    
    struct pw_proxy *proxy = (struct pw_proxy *)pw_core_create_object(
        core,
        "link-factory",
        PW_TYPE_INTERFACE_Link,
        PW_VERSION_LINK,
        &props,
        0
    );
    
    if (proxy == NULL) {
        return -EIO;
    }
    
    return 0;
}

/**
 * 
 * @param core PipeWire core
 * @param loop Thread loop
 * @param seq Sequence number to wait for
 * @return Final sequence number
 */
int gpw_sync_core(struct pw_core *core, struct pw_thread_loop *loop, int seq)
{
    if (core == NULL || loop == NULL) {
        return -EINVAL;
    }
    
    return pw_core_sync(core, PW_ID_CORE, seq);
}

/**
 * 
 * @param registry Registry to destroy
 */
void gpw_registry_destroy(struct pw_registry *registry)
{
    if (registry) {
        pw_proxy_destroy((struct pw_proxy*)registry);
    }
}


void gpw_core_add_listener(struct pw_core *core,
                           struct spa_hook *listener,
                           const struct pw_core_events *events,
                           void *data)
{
    pw_core_add_listener(core, listener, events, data);
}


void gpw_registry_add_listener(struct pw_registry *registry,
                               struct spa_hook *listener,
                               const struct pw_registry_events *events,
                               void *data)
{
    pw_registry_add_listener(registry, listener, events, data);
}

