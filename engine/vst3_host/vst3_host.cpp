#include "vst3_host.h"

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <cstring>
#include <filesystem>

// VST3 SDK includes
#include "pluginterfaces/vst/ivstaudioprocessor.h"
#include "pluginterfaces/vst/ivsteditcontroller.h"
#include "pluginterfaces/vst/ivstcomponent.h"
#include "pluginterfaces/vst/ivstprocesscontext.h"
#include "pluginterfaces/vst/ivstparameterchanges.h"
#include "pluginterfaces/vst/ivstevents.h"
#include "public.sdk/source/vst/hosting/module.h"
#include "public.sdk/source/vst/hosting/hostclasses.h"
#include "public.sdk/source/vst/hosting/plugprovider.h"

using namespace Steinberg;
using namespace Steinberg::Vst;

namespace fs = std::filesystem;

// Global error message
static std::string g_last_error;

// Global host application
static IPtr<HostApplication> g_host_app;

// Plugin instance wrapper
struct VST3PluginInstance {
    IPtr<IComponent> component;
    IPtr<IAudioProcessor> processor;
    IPtr<IEditController> controller;
    std::string file_path;
    VST3::Hosting::Module::Ptr module;

    // Audio setup
    double sample_rate;
    int max_block_size;
    bool initialized;
    bool active;

    // Processing buffers
    ProcessData process_data;

    // Event list for MIDI
    IPtr<IEventList> event_list;

    VST3PluginInstance()
        : sample_rate(44100.0)
        , max_block_size(512)
        , initialized(false)
        , active(false) {
        std::memset(&process_data, 0, sizeof(ProcessData));
    }
};

// Helper function to set error message
static void set_error(const std::string& error) {
    g_last_error = error;
}

// C API Implementation

bool vst3_host_init() {
    // Initialize host application
    if (!g_host_app) {
        g_host_app = owned(new HostApplication());
    }
    return true;
}

void vst3_host_shutdown() {
    // Cleanup global resources
    g_host_app = nullptr;
    g_last_error.clear();
}

int vst3_scan_directory(const char* directory, VST3ScanCallback callback, void* user_data) {
    if (!directory || !callback) {
        set_error("Invalid parameters");
        return 0;
    }

    int count = 0;

    try {
        fs::path dir_path(directory);
        if (!fs::exists(dir_path) || !fs::is_directory(dir_path)) {
            set_error("Directory does not exist");
            return 0;
        }

        // Scan for .vst3 bundles/folders
        for (const auto& entry : fs::recursive_directory_iterator(dir_path)) {
            if (entry.is_directory() && entry.path().extension() == ".vst3") {
                std::string plugin_path = entry.path().string();

                // Try to load the module
                std::string error;
                auto module = VST3::Hosting::Module::create(plugin_path, error);
                if (!module) continue;

                auto factory = module->getFactory();

                // Get factory info
                PFactoryInfo factory_info;
                factory.get()->getFactoryInfo(&factory_info);

                // Iterate through all class infos
                for (const auto& class_info : factory.classInfos()) {
                    // Check if it's an audio module component
                    if (class_info.category() == kVstAudioEffectClass) {
                        VST3PluginInfo info;
                        std::memset(&info, 0, sizeof(VST3PluginInfo));

                        std::strncpy(info.name, class_info.name().c_str(), sizeof(info.name) - 1);
                        std::strncpy(info.vendor, factory_info.vendor, sizeof(info.vendor) - 1);
                        std::strncpy(info.file_path, plugin_path.c_str(), sizeof(info.file_path) - 1);

                        // Try to determine if it's an instrument or effect
                        // Default to effect for now
                        info.is_effect = true;
                        info.is_instrument = false;

                        callback(&info, user_data);
                        count++;
                    }
                }
            }
        }
    } catch (const std::exception& e) {
        set_error(std::string("Scan error: ") + e.what());
        return count;
    }

    return count;
}

int vst3_scan_standard_locations(VST3ScanCallback callback, void* user_data) {
    int total = 0;

    // Standard VST3 locations on macOS
    std::vector<std::string> locations = {
        "/Library/Audio/Plug-Ins/VST3",
        std::string(getenv("HOME")) + "/Library/Audio/Plug-Ins/VST3"
    };

    for (const auto& location : locations) {
        total += vst3_scan_directory(location.c_str(), callback, user_data);
    }

    return total;
}

VST3PluginHandle vst3_load_plugin(const char* file_path) {
    if (!file_path) {
        set_error("Invalid file path");
        return nullptr;
    }

    if (!g_host_app) {
        set_error("Host not initialized. Call vst3_host_init() first");
        return nullptr;
    }

    try {
        auto instance = std::make_unique<VST3PluginInstance>();
        instance->file_path = file_path;

        // Load the module
        std::string error;
        auto module = VST3::Hosting::Module::create(file_path, error);
        if (!module) {
            set_error("Failed to load module: " + error);
            return nullptr;
        }

        instance->module = module;

        auto factory = module->getFactory();

        // Find the first audio effect class
        for (const auto& class_info : factory.classInfos()) {
            if (class_info.category() == kVstAudioEffectClass) {
                // Create the component using modern API
                auto component = factory.createInstance<IComponent>(class_info.ID());
                if (!component) {
                    set_error("Failed to create component instance");
                    return nullptr;
                }

                instance->component = component;

                // Initialize the component
                if (component->initialize(g_host_app) != kResultOk) {
                    set_error("Failed to initialize component");
                    return nullptr;
                }

                // Get the audio processor interface
                auto processor = FUnknownPtr<IAudioProcessor>(component);
                if (processor) {
                    instance->processor = processor;
                }

                // Get the edit controller
                TUID controller_cid;
                if (component->getControllerClassId(controller_cid) == kResultOk) {
                    auto controller = factory.createInstance<IEditController>(VST3::UID::fromTUID(controller_cid));
                    if (controller) {
                        instance->controller = controller;
                        controller->initialize(g_host_app);
                    }
                }

                return instance.release();
            }
        }

        set_error("No audio effect class found in plugin");
        return nullptr;

    } catch (const std::exception& e) {
        set_error(std::string("Load error: ") + e.what());
        return nullptr;
    }
}

void vst3_unload_plugin(VST3PluginHandle handle) {
    if (!handle) return;

    auto instance = static_cast<VST3PluginInstance*>(handle);

    // Deactivate if active
    if (instance->active && instance->processor) {
        instance->processor->setProcessing(false);
        instance->active = false;
    }

    // Cleanup
    if (instance->controller) {
        instance->controller->terminate();
    }

    if (instance->component) {
        instance->component->terminate();
    }

    delete instance;
}

bool vst3_get_plugin_info(VST3PluginHandle handle, VST3PluginInfo* info) {
    if (!handle || !info) {
        set_error("Invalid parameters");
        return false;
    }

    auto instance = static_cast<VST3PluginInstance*>(handle);
    std::memset(info, 0, sizeof(VST3PluginInfo));

    // Get info from component
    PFactoryInfo factory_info;
    std::strncpy(info->file_path, instance->file_path.c_str(), sizeof(info->file_path) - 1);

    // TODO: Extract more detailed info from component
    info->is_effect = true;
    info->is_instrument = false;

    return true;
}

bool vst3_initialize_plugin(VST3PluginHandle handle, double sample_rate, int max_block_size) {
    if (!handle) {
        set_error("Invalid handle");
        return false;
    }

    auto instance = static_cast<VST3PluginInstance*>(handle);
    if (!instance->processor) {
        set_error("No audio processor interface");
        return false;
    }

    instance->sample_rate = sample_rate;
    instance->max_block_size = max_block_size;

    // Setup processing
    ProcessSetup setup;
    setup.processMode = kRealtime;
    setup.symbolicSampleSize = kSample32;
    setup.maxSamplesPerBlock = max_block_size;
    setup.sampleRate = sample_rate;

    if (instance->processor->setupProcessing(setup) != kResultOk) {
        set_error("Failed to setup processing");
        return false;
    }

    // Activate busses
    if (instance->component->activateBus(kAudio, kInput, 0, true) != kResultOk) {
        // Some plugins don't have input (instruments)
    }

    if (instance->component->activateBus(kAudio, kOutput, 0, true) != kResultOk) {
        set_error("Failed to activate output bus");
        return false;
    }

    instance->initialized = true;
    return true;
}

bool vst3_activate_plugin(VST3PluginHandle handle) {
    if (!handle) {
        set_error("Invalid handle");
        return false;
    }

    auto instance = static_cast<VST3PluginInstance*>(handle);
    if (!instance->initialized || !instance->processor) {
        set_error("Plugin not initialized");
        return false;
    }

    if (instance->processor->setProcessing(true) != kResultOk) {
        set_error("Failed to start processing");
        return false;
    }

    instance->active = true;
    return true;
}

bool vst3_deactivate_plugin(VST3PluginHandle handle) {
    if (!handle) return false;

    auto instance = static_cast<VST3PluginInstance*>(handle);
    if (instance->active && instance->processor) {
        instance->processor->setProcessing(false);
        instance->active = false;
    }

    return true;
}

bool vst3_process_audio(
    VST3PluginHandle handle,
    const float* input_left,
    const float* input_right,
    float* output_left,
    float* output_right,
    int num_frames
) {
    if (!handle) {
        set_error("Invalid handle");
        return false;
    }

    auto instance = static_cast<VST3PluginInstance*>(handle);
    if (!instance->active || !instance->processor) {
        set_error("Plugin not active");
        return false;
    }

    // TODO: Implement proper audio buffer setup and processing
    // This is a simplified version - real implementation needs proper buffer management

    return true;
}

bool vst3_process_midi_event(
    VST3PluginHandle handle,
    int event_type,
    int channel,
    int data1,
    int data2,
    int sample_offset
) {
    // TODO: Implement MIDI event processing
    return false;
}

int vst3_get_parameter_count(VST3PluginHandle handle) {
    if (!handle) return 0;

    auto instance = static_cast<VST3PluginInstance*>(handle);
    if (!instance->controller) return 0;

    return instance->controller->getParameterCount();
}

bool vst3_get_parameter_info(VST3PluginHandle handle, int index, VST3ParameterInfo* info) {
    if (!handle || !info) return false;

    auto instance = static_cast<VST3PluginInstance*>(handle);
    if (!instance->controller) return false;

    ParameterInfo param_info;
    if (instance->controller->getParameterInfo(index, param_info) != kResultOk) {
        return false;
    }

    std::memset(info, 0, sizeof(VST3ParameterInfo));
    info->id = param_info.id;

    // Convert from UTF16 to UTF8 (simplified - real implementation needs proper conversion)
    for (int i = 0; i < 255 && param_info.title[i]; i++) {
        info->title[i] = static_cast<char>(param_info.title[i]);
    }

    info->default_value = param_info.defaultNormalizedValue;
    info->step_count = param_info.stepCount;

    return true;
}

double vst3_get_parameter_value(VST3PluginHandle handle, uint32_t param_id) {
    if (!handle) return 0.0;

    auto instance = static_cast<VST3PluginInstance*>(handle);
    if (!instance->controller) return 0.0;

    return instance->controller->getParamNormalized(param_id);
}

bool vst3_set_parameter_value(VST3PluginHandle handle, uint32_t param_id, double value) {
    if (!handle) return false;

    auto instance = static_cast<VST3PluginInstance*>(handle);
    if (!instance->controller) return false;

    return instance->controller->setParamNormalized(param_id, value) == kResultOk;
}

int vst3_get_state_size(VST3PluginHandle handle) {
    // TODO: Implement state size query
    return 0;
}

int vst3_get_state(VST3PluginHandle handle, void* data, int max_size) {
    // TODO: Implement state save
    return -1;
}

bool vst3_set_state(VST3PluginHandle handle, const void* data, int size) {
    // TODO: Implement state load
    return false;
}

const char* vst3_get_last_error() {
    return g_last_error.c_str();
}
