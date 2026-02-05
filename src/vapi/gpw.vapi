[CCode (cheader_filename = "pipewire_wrapper.h")]
namespace GPW {
    [CCode (cname = "gpw_create_link")]
    public int create_link (PipeWire.Core core,
                            uint32 output_node_id,
                            uint32 output_port_id,
                            uint32 input_node_id,
                            uint32 input_port_id);
    
    [CCode (cname = "gpw_sync_core")]
    public int sync_core (PipeWire.Core core, PipeWire.ThreadLoop loop, int seq);

    [CCode (cname = "gpw_core_add_listener")]
    public void core_add_listener (PipeWire.Core core,
                                   ref SPA.Hook listener,
                                   ref GPW.CoreEvents events,
                                   void* data);

    [CCode (cname = "gpw_registry_add_listener")]
    public void registry_add_listener (PipeWire.Registry registry,
                                       ref SPA.Hook listener,
                                       ref GPW.RegistryEvents events,
                                       void* data);

    [CCode (has_target = false)]
    public delegate void CoreDoneFunc (void *data, uint32 id, int seq);
    
    [CCode (has_target = false)]
    public delegate void CoreErrorCallback (void *data, uint32 id, int seq, int res, unowned string message);

    [CCode (cname = "struct pw_core_events", has_type_id = false)]
    public struct CoreEvents {
        public uint32 version;
        public void* info;
        public CoreDoneFunc done;
        public CoreErrorCallback error;
    }

    [CCode (has_target = false)]
    public delegate void GlobalFunc (void *data, uint32 id, uint32 permissions, unowned string type, uint32 version, [CCode (type = "const struct spa_dict*")] SPA.Dict? props);

    [CCode (has_target = false)]
    public delegate void GlobalRemoveFunc (void *data, uint32 id);

    [CCode (cname = "struct pw_registry_events", has_type_id = false)]
    public struct RegistryEvents {
        public uint32 version;
        public GlobalFunc global;
        public GlobalRemoveFunc global_remove;
    }
}
