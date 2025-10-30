use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_double, c_float, c_int, c_void};
use std::ptr;

// C FFI bindings to the C++ VST3 host library

/// Opaque plugin handle
#[repr(C)]
pub struct VST3PluginHandle {
    _private: [u8; 0],
}

/// Plugin info structure (matches C header)
#[repr(C)]
#[derive(Debug, Clone)]
pub struct VST3PluginInfo {
    pub name: [c_char; 256],
    pub vendor: [c_char; 256],
    pub version: [c_char; 64],
    pub category: [c_char; 64],
    pub file_path: [c_char; 1024],
    pub is_instrument: bool,
    pub is_effect: bool,
}

impl VST3PluginInfo {
    pub fn name_str(&self) -> &str {
        unsafe {
            CStr::from_ptr(self.name.as_ptr())
                .to_str()
                .unwrap_or("")
        }
    }

    pub fn vendor_str(&self) -> &str {
        unsafe {
            CStr::from_ptr(self.vendor.as_ptr())
                .to_str()
                .unwrap_or("")
        }
    }

    pub fn file_path_str(&self) -> &str {
        unsafe {
            CStr::from_ptr(self.file_path.as_ptr())
                .to_str()
                .unwrap_or("")
        }
    }
}

/// Parameter info structure
#[repr(C)]
#[derive(Debug, Clone)]
pub struct VST3ParameterInfo {
    pub id: u32,
    pub title: [c_char; 256],
    pub short_title: [c_char; 64],
    pub units: [c_char; 64],
    pub default_value: c_double,
    pub min_value: c_double,
    pub max_value: c_double,
    pub step_count: c_int,
}

impl VST3ParameterInfo {
    pub fn title_str(&self) -> &str {
        unsafe {
            CStr::from_ptr(self.title.as_ptr())
                .to_str()
                .unwrap_or("")
        }
    }

    pub fn units_str(&self) -> &str {
        unsafe {
            CStr::from_ptr(self.units.as_ptr())
                .to_str()
                .unwrap_or("")
        }
    }
}

/// Scan callback type
pub type VST3ScanCallback = extern "C" fn(*const VST3PluginInfo, *mut c_void);

// External C functions from the C++ library
extern "C" {
    pub fn vst3_host_init() -> bool;
    pub fn vst3_host_shutdown();

    pub fn vst3_scan_directory(
        directory: *const c_char,
        callback: VST3ScanCallback,
        user_data: *mut c_void,
    ) -> c_int;

    pub fn vst3_scan_standard_locations(
        callback: VST3ScanCallback,
        user_data: *mut c_void,
    ) -> c_int;

    pub fn vst3_load_plugin(file_path: *const c_char) -> *mut VST3PluginHandle;
    pub fn vst3_unload_plugin(handle: *mut VST3PluginHandle);

    pub fn vst3_get_plugin_info(
        handle: *mut VST3PluginHandle,
        info: *mut VST3PluginInfo,
    ) -> bool;

    pub fn vst3_initialize_plugin(
        handle: *mut VST3PluginHandle,
        sample_rate: c_double,
        max_block_size: c_int,
    ) -> bool;

    pub fn vst3_activate_plugin(handle: *mut VST3PluginHandle) -> bool;
    pub fn vst3_deactivate_plugin(handle: *mut VST3PluginHandle) -> bool;

    pub fn vst3_process_audio(
        handle: *mut VST3PluginHandle,
        input_left: *const c_float,
        input_right: *const c_float,
        output_left: *mut c_float,
        output_right: *mut c_float,
        num_frames: c_int,
    ) -> bool;

    pub fn vst3_process_midi_event(
        handle: *mut VST3PluginHandle,
        event_type: c_int,
        channel: c_int,
        data1: c_int,
        data2: c_int,
        sample_offset: c_int,
    ) -> bool;

    pub fn vst3_get_parameter_count(handle: *mut VST3PluginHandle) -> c_int;

    pub fn vst3_get_parameter_info(
        handle: *mut VST3PluginHandle,
        index: c_int,
        info: *mut VST3ParameterInfo,
    ) -> bool;

    pub fn vst3_get_parameter_value(
        handle: *mut VST3PluginHandle,
        param_id: u32,
    ) -> c_double;

    pub fn vst3_set_parameter_value(
        handle: *mut VST3PluginHandle,
        param_id: u32,
        value: c_double,
    ) -> bool;

    pub fn vst3_get_state_size(handle: *mut VST3PluginHandle) -> c_int;

    pub fn vst3_get_state(
        handle: *mut VST3PluginHandle,
        data: *mut c_void,
        max_size: c_int,
    ) -> c_int;

    pub fn vst3_set_state(
        handle: *mut VST3PluginHandle,
        data: *const c_void,
        size: c_int,
    ) -> bool;

    pub fn vst3_get_last_error() -> *const c_char;
}

// Rust-safe wrapper API

pub struct VST3Host;

impl VST3Host {
    pub fn init() -> Result<(), String> {
        unsafe {
            if vst3_host_init() {
                Ok(())
            } else {
                Err(Self::get_last_error())
            }
        }
    }

    pub fn shutdown() {
        unsafe {
            vst3_host_shutdown();
        }
    }

    pub fn scan_directory<F>(directory: &str, mut callback: F) -> Result<usize, String>
    where
        F: FnMut(&VST3PluginInfo),
    {
        let dir_cstr = CString::new(directory).map_err(|e| e.to_string())?;

        extern "C" fn scan_callback<F>(info: *const VST3PluginInfo, user_data: *mut c_void)
        where
            F: FnMut(&VST3PluginInfo),
        {
            unsafe {
                let callback = &mut *(user_data as *mut F);
                if !info.is_null() {
                    callback(&*info);
                }
            }
        }

        unsafe {
            let count = vst3_scan_directory(
                dir_cstr.as_ptr(),
                scan_callback::<F>,
                &mut callback as *mut F as *mut c_void,
            );

            if count >= 0 {
                Ok(count as usize)
            } else {
                Err(Self::get_last_error())
            }
        }
    }

    pub fn scan_standard_locations<F>(mut callback: F) -> Result<usize, String>
    where
        F: FnMut(&VST3PluginInfo),
    {
        extern "C" fn scan_callback<F>(info: *const VST3PluginInfo, user_data: *mut c_void)
        where
            F: FnMut(&VST3PluginInfo),
        {
            unsafe {
                let callback = &mut *(user_data as *mut F);
                if !info.is_null() {
                    callback(&*info);
                }
            }
        }

        unsafe {
            let count = vst3_scan_standard_locations(
                scan_callback::<F>,
                &mut callback as *mut F as *mut c_void,
            );

            if count >= 0 {
                Ok(count as usize)
            } else {
                Err(Self::get_last_error())
            }
        }
    }

    fn get_last_error() -> String {
        unsafe {
            let err_ptr = vst3_get_last_error();
            if err_ptr.is_null() {
                "Unknown error".to_string()
            } else {
                CStr::from_ptr(err_ptr)
                    .to_string_lossy()
                    .into_owned()
            }
        }
    }
}

pub struct VST3Plugin {
    handle: *mut VST3PluginHandle,
}

impl VST3Plugin {
    pub fn load(file_path: &str) -> Result<Self, String> {
        let path_cstr = CString::new(file_path).map_err(|e| e.to_string())?;

        unsafe {
            let handle = vst3_load_plugin(path_cstr.as_ptr());
            if handle.is_null() {
                Err(VST3Host::get_last_error())
            } else {
                Ok(VST3Plugin { handle })
            }
        }
    }

    pub fn get_info(&self) -> Result<VST3PluginInfo, String> {
        let mut info: VST3PluginInfo = unsafe { std::mem::zeroed() };

        unsafe {
            if vst3_get_plugin_info(self.handle, &mut info) {
                Ok(info)
            } else {
                Err(VST3Host::get_last_error())
            }
        }
    }

    pub fn initialize(&self, sample_rate: f64, max_block_size: i32) -> Result<(), String> {
        unsafe {
            if vst3_initialize_plugin(self.handle, sample_rate, max_block_size) {
                Ok(())
            } else {
                Err(VST3Host::get_last_error())
            }
        }
    }

    pub fn activate(&self) -> Result<(), String> {
        unsafe {
            if vst3_activate_plugin(self.handle) {
                Ok(())
            } else {
                Err(VST3Host::get_last_error())
            }
        }
    }

    pub fn deactivate(&self) -> Result<(), String> {
        unsafe {
            if vst3_deactivate_plugin(self.handle) {
                Ok(())
            } else {
                Err(VST3Host::get_last_error())
            }
        }
    }

    pub fn process_audio(
        &self,
        input_left: &[f32],
        input_right: &[f32],
        output_left: &mut [f32],
        output_right: &mut [f32],
    ) -> Result<(), String> {
        let num_frames = input_left.len().min(output_left.len()) as i32;

        unsafe {
            if vst3_process_audio(
                self.handle,
                input_left.as_ptr(),
                input_right.as_ptr(),
                output_left.as_mut_ptr(),
                output_right.as_mut_ptr(),
                num_frames,
            ) {
                Ok(())
            } else {
                Err(VST3Host::get_last_error())
            }
        }
    }

    pub fn process_midi_event(
        &self,
        event_type: i32,
        channel: i32,
        data1: i32,
        data2: i32,
        sample_offset: i32,
    ) -> Result<(), String> {
        unsafe {
            if vst3_process_midi_event(
                self.handle,
                event_type,
                channel,
                data1,
                data2,
                sample_offset,
            ) {
                Ok(())
            } else {
                Err(VST3Host::get_last_error())
            }
        }
    }

    pub fn get_parameter_count(&self) -> i32 {
        unsafe { vst3_get_parameter_count(self.handle) }
    }

    pub fn get_parameter_info(&self, index: i32) -> Result<VST3ParameterInfo, String> {
        let mut info: VST3ParameterInfo = unsafe { std::mem::zeroed() };

        unsafe {
            if vst3_get_parameter_info(self.handle, index, &mut info) {
                Ok(info)
            } else {
                Err(VST3Host::get_last_error())
            }
        }
    }

    pub fn get_parameter_value(&self, param_id: u32) -> f64 {
        unsafe { vst3_get_parameter_value(self.handle, param_id) }
    }

    pub fn set_parameter_value(&self, param_id: u32, value: f64) -> Result<(), String> {
        unsafe {
            if vst3_set_parameter_value(self.handle, param_id, value) {
                Ok(())
            } else {
                Err(VST3Host::get_last_error())
            }
        }
    }

    pub fn get_state(&self) -> Result<Vec<u8>, String> {
        unsafe {
            let size = vst3_get_state_size(self.handle);
            if size <= 0 {
                return Ok(Vec::new());
            }

            let mut buffer = vec![0u8; size as usize];
            let actual_size = vst3_get_state(
                self.handle,
                buffer.as_mut_ptr() as *mut c_void,
                size,
            );

            if actual_size > 0 {
                buffer.truncate(actual_size as usize);
                Ok(buffer)
            } else {
                Err(VST3Host::get_last_error())
            }
        }
    }

    pub fn set_state(&self, data: &[u8]) -> Result<(), String> {
        unsafe {
            if vst3_set_state(
                self.handle,
                data.as_ptr() as *const c_void,
                data.len() as i32,
            ) {
                Ok(())
            } else {
                Err(VST3Host::get_last_error())
            }
        }
    }
}

impl Drop for VST3Plugin {
    fn drop(&mut self) {
        if !self.handle.is_null() {
            unsafe {
                vst3_unload_plugin(self.handle);
            }
        }
    }
}

unsafe impl Send for VST3Plugin {}
unsafe impl Sync for VST3Plugin {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vst3_host_init() {
        assert!(VST3Host::init().is_ok());
        VST3Host::shutdown();
    }

    #[test]
    fn test_vst3_scan() {
        VST3Host::init().unwrap();

        let mut count = 0;
        VST3Host::scan_standard_locations(|info| {
            println!("Found plugin: {} by {}", info.name_str(), info.vendor_str());
            count += 1;
        }).ok();

        println!("Found {} plugins", count);
        VST3Host::shutdown();
    }
}
