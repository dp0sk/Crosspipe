[CCode (cheader_filename = "pipewire/pipewire.h")]
namespace PipeWire {
    [CCode (cname = "pw_init")]
    public void init (void *argc, void *argv);

    [CCode (cname = "pw_deinit")]
    public void deinit ();
    
    [CCode (cname = "pw_get_library_version")]
    public unowned string get_library_version();

    // ID Constants
    [CCode (cname = "PW_ID_CORE")]
    public const uint32 ID_CORE;

    [CCode (cname = "struct pw_loop", has_type_id = false)]
    [Compact]
    public class Loop {
    }

    [CCode (cname = "struct pw_thread_loop", free_function = "pw_thread_loop_destroy", has_type_id = false)]
    [Compact]
    public class ThreadLoop {
        [CCode (cname = "pw_thread_loop_new")]
        public ThreadLoop (string name, [CCode (array_length = false)] string[]? properties);
        
        [CCode (cname = "pw_thread_loop_start")]
        public int start ();
        
        [CCode (cname = "pw_thread_loop_stop")]
        public void stop ();
        
        [CCode (cname = "pw_thread_loop_lock")]
        public void lock ();
        
        [CCode (cname = "pw_thread_loop_unlock")]
        public void unlock ();
        
        [CCode (cname = "pw_thread_loop_get_loop")]
        public unowned Loop get_loop ();
        
        [CCode (cname = "pw_thread_loop_signal")]
        public void signal (bool wait);
        
        [CCode (cname = "pw_thread_loop_wait")]
        public void wait ();
        
        [CCode (cname = "pw_thread_loop_in_thread")]
        public bool in_thread ();
    }

    [CCode (cname = "struct pw_context", free_function = "pw_context_destroy", has_type_id = false)]
    [Compact]
    public class Context {
        [CCode (cname = "pw_context_new")]
        public Context (Loop loop, [CCode (array_length = false)] string[]? properties, size_t user_data_size);
        
        [CCode (cname = "pw_context_connect")]
        public Core? connect ([CCode (array_length = false)] string[]? properties, size_t user_data_size);
    }

    [CCode (cname = "struct pw_proxy", free_function = "pw_proxy_destroy", has_type_id = false)]
    [Compact]
    public class Proxy {
        [CCode (cname = "pw_proxy_add_listener")]
        public void add_listener (ref SPA.Hook listener, ProxyEvents? events, void* data);
        
        [CCode (cname = "pw_proxy_sync")]
        public int sync (int seq);
        
        [CCode (cname = "pw_proxy_get_user_data")]
        public void* get_user_data ();
    }
    
    [CCode (cname = "PW_VERSION_PROXY_EVENTS")]
    public const uint32 VERSION_PROXY_EVENTS;
    
    [CCode (cname = "struct pw_proxy_events", has_type_id = false)]
    public struct ProxyEvents {
        public uint32 version;
        [CCode (delegate_target = false)]
        public ProxyDestroyCallback? destroy;
        [CCode (delegate_target = false)]
        public ProxyRemovedCallback? removed;
        [CCode (delegate_target = false)]
        public ProxyErrorCallback? error;
    }
    
    [CCode (cname = "pw_proxy_destroy_callback", instance_pos = 0)]
    public delegate void ProxyDestroyCallback (void* data);
    
    [CCode (cname = "pw_proxy_removed_callback", instance_pos = 0)]
    public delegate void ProxyRemovedCallback (void* data);
    
    [CCode (cname = "pw_proxy_error_callback", instance_pos = 0)]
    public delegate void ProxyErrorCallback (void* data, int seq, int res, unowned string message);

    [CCode (cname = "struct pw_core", free_function = "pw_core_disconnect", has_type_id = false)]
    [Compact]
    public class Core {
        [CCode (cname = "pw_core_get_registry")]
        public Registry? get_registry (uint32 version, size_t user_data_size);
        
        [CCode (cname = "pw_core_add_listener")]
        public void add_listener (ref SPA.Hook listener, CoreEvents? events, void* data);
        
        [CCode (cname = "pw_core_sync")]
        public int sync (uint32 id, int seq);
        
        [CCode (cname = "pw_core_create_object")]
        public Proxy? create_object (unowned string factory_name, unowned string type, uint32 version, [CCode (type = "const struct spa_dict*")] SPA.Dict? props, size_t user_data_size);
    }
    
    [CCode (cname = "PW_VERSION_CORE_EVENTS")]
    public const uint32 VERSION_CORE_EVENTS;
    
    [CCode (cname = "struct pw_core_events", has_type_id = false)]
    public struct CoreEvents {
        public uint32 version;
        [CCode (delegate_target = false)]
        public void* info;
        [CCode (delegate_target = false)]
        public CoreDoneCallback? done;
        [CCode (delegate_target = false)]
        public CoreErrorCallback? error;
    }
    
    [CCode (cname = "pw_core_done_callback", instance_pos = 0)]
    public delegate void CoreDoneCallback (void* data, uint32 id, int seq);
    
    [CCode (cname = "pw_core_error_callback", instance_pos = 0)]
    public delegate void CoreErrorCallback (void* data, uint32 id, int seq, int res, unowned string message);

    [CCode (cname = "struct pw_registry", free_function = "gpw_registry_destroy", cheader_filename = "pipewire_wrapper.h", has_type_id = false)]
    [Compact]
    public class Registry {
        [CCode (cname = "pw_registry_add_listener")]
        public void add_listener (ref SPA.Hook listener, RegistryEvents? events, void* data);
        
        [CCode (cname = "pw_registry_destroy")]
        public int destroy (uint32 id);
        
        [CCode (cname = "pw_registry_bind")]
        public Proxy? bind (uint32 id, unowned string type, uint32 version, size_t user_data_size);
    }
    
    [CCode (cname = "PW_VERSION_REGISTRY_EVENTS")]
    public const uint32 VERSION_REGISTRY_EVENTS;
    
    [CCode (cname = "struct pw_registry_events", has_type_id = false)]
    public struct RegistryEvents {
        public uint32 version;
        [CCode (delegate_target = false)]
        public GlobalCallback global;
        [CCode (delegate_target = false)]
        public GlobalRemoveCallback global_remove;
    }

    [CCode (cname = "pw_registry_global_callback", instance_pos = 0)]
    public delegate void GlobalCallback (void *data, uint32 id, uint32 permissions, unowned string type, uint32 version, [CCode (type = "const struct spa_dict*")] SPA.Dict? props);
    
    [CCode (cname = "pw_registry_global_remove_callback", instance_pos = 0)]
    public delegate void GlobalRemoveCallback (void *data, uint32 id);

    // Interface types
    public class Node {
        [CCode (cname = "PW_TYPE_INTERFACE_Node")]
        public const string INTERFACE_NAME;
        
        [CCode (cname = "PW_VERSION_NODE")]
        public const uint32 VERSION;
    }
    
    public class Port {
        [CCode (cname = "PW_TYPE_INTERFACE_Port")]
        public const string INTERFACE_NAME;
        
        [CCode (cname = "PW_VERSION_PORT")]
        public const uint32 VERSION;
    }
    
    public class Link {
        [CCode (cname = "PW_TYPE_INTERFACE_Link")]
        public const string INTERFACE_NAME;
        
        [CCode (cname = "PW_VERSION_LINK")]
        public const uint32 VERSION;
    }
    
    // PW_KEY constants for properties
    [CCode (cname = "PW_KEY_LINK_OUTPUT_NODE")]
    public const string KEY_LINK_OUTPUT_NODE;
    
    [CCode (cname = "PW_KEY_LINK_OUTPUT_PORT")]
    public const string KEY_LINK_OUTPUT_PORT;
    
    [CCode (cname = "PW_KEY_LINK_INPUT_NODE")]
    public const string KEY_LINK_INPUT_NODE;
    
    [CCode (cname = "PW_KEY_LINK_INPUT_PORT")]
    public const string KEY_LINK_INPUT_PORT;
    
    [CCode (cname = "PW_KEY_OBJECT_LINGER")]
    public const string KEY_OBJECT_LINGER;
    
    [CCode (cname = "PW_KEY_LINK_PASSIVE")]
    public const string KEY_LINK_PASSIVE;
    
    [CCode (cname = "PW_KEY_NODE_ID")]
    public const string KEY_NODE_ID;
    
    [CCode (cname = "PW_KEY_NODE_NAME")]
    public const string KEY_NODE_NAME;
    
    [CCode (cname = "PW_KEY_NODE_NICK")]
    public const string KEY_NODE_NICK;
    
    [CCode (cname = "PW_KEY_NODE_DESCRIPTION")]
    public const string KEY_NODE_DESCRIPTION;
    
    [CCode (cname = "PW_KEY_PORT_NAME")]
    public const string KEY_PORT_NAME;
    
    [CCode (cname = "PW_KEY_PORT_ALIAS")]
    public const string KEY_PORT_ALIAS;
    
    [CCode (cname = "PW_KEY_PORT_DIRECTION")]
    public const string KEY_PORT_DIRECTION;
    
    [CCode (cname = "PW_KEY_FORMAT_DSP")]
    public const string KEY_FORMAT_DSP;
    
    [CCode (cname = "PW_KEY_MEDIA_CLASS")]
    public const string KEY_MEDIA_CLASS;
    
    [CCode (cname = "PW_KEY_MEDIA_NAME")]
    public const string KEY_MEDIA_NAME;
    
    [CCode (cname = "PW_KEY_APP_NAME")]
    public const string KEY_APP_NAME;
    
    [CCode (cname = "PW_KEY_APP_ICON_NAME")]
    public const string KEY_APP_ICON_NAME;
}

[CCode (cheader_filename = "spa/utils/hook.h", cprefix = "spa_hook_", lower_case_cprefix = "spa_hook_")]
namespace SPA {
    [CCode (cname = "struct spa_hook", has_type_id = false, destroy_function = "spa_hook_remove")]
    public struct Hook {
        public void remove ();
    }
    
    [CCode (cname = "struct spa_dict", has_type_id = false, cheader_filename = "spa/utils/dict.h")]
    public struct Dict {
        public uint32 flags;
        public uint32 n_items;
        [CCode (cname = "items", array_length_cname = "n_items")]
        public DictItem[] items;
        
        [CCode (cname = "spa_dict_lookup")]
        public unowned string? lookup (string key);
        
        public string? get (string key) {
            return lookup (key);
        }
    }
    
    [CCode (cname = "struct spa_dict_item", has_type_id = false, cheader_filename = "spa/utils/dict.h")]
    public struct DictItem {
        public unowned string key;
        public unowned string value;
    }
    
    [CCode (cname = "SPA_DICT_INIT", cheader_filename = "spa/utils/dict.h")]
    public static Dict dict_init ([CCode (array_length = false)] DictItem[] items, uint32 n_items);
    
    [CCode (cname = "SPA_DICT_ITEM_INIT", cheader_filename = "spa/utils/dict.h")]
    public static DictItem dict_item_init (string key, string value);
}
