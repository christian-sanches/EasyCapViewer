# Phase 6 — USB Drivers Modernization

**Goal:** Verify and update the IOKit USB device drivers for Apple Silicon compatibility. The drivers should largely work since IOKit is still available, but there may be subtle differences.

---

## 6.1 Current USB Architecture

All USB device access uses IOKit directly:

```
ECVController → IOServiceGetMatchingServices(kIOFirstMatchNotification)
                     ↓
              IOUSBInterfaceInterface300 (or similar)
                     ↓
              ECVUSBTransferList (isochronous transfers)
                     ↓
              ECVSTK1160Device / ECVEM2860Device / ECVSomagicDevice / ECVFushicaiDevice
```

### Device drivers
| File | Chipset | USB Protocol |
|------|---------|-------------|
| `ECVSTK1160Device.h/m` | Syntek STK1160 | Isochronous video + bulk audio |
| `stk11xx.h` | STK1160 register access | USB bulk control |
| `stk11xx-dev-0408.m` | STK1160 device specifics | USB register read/write |
| `ECVEM2860Device.h/m` | Empia EM2860 | Isochronous video + bulk audio + GPIO |
| `ECVSomagicDevice.h/m` | Somagic | Firmware upload + isochronous video |
| `ECVSomagicDevice_Unloaded.h/m` | Somagic (stub) | No-op when firmware unavailable |
| `ECVFushicaiDevice.h/m` | Fushicai | Isochronous video + bulk audio + mode switching |

### USB transfer model
`ECVUSBTransferList` manages a ring buffer of `IOUSBLowLatencyIsocFrame` structures for high-throughput isochronous USB transfers. This is the core data path for all video capture.

---

## 6.2 Apple Silicon Compatibility

### What should work as-is
- `IOServiceMatching` / `IOServiceGetMatchingServices` — standard IOKit
- `IOUSBDeviceInterface` — USB device enumeration
- `IOUSBInterfaceInterface` — USB interface access
- `IOUSBFindEndpointDict` — endpoint discovery

### Potential issues

#### 1. `IOUSBLowLatencyIsocFrame`
This API is designed for real-time isochronous transfers. On Apple Silicon:
- **Should work** — IOKit USB APIs are still available
- **Verify** that low-latency isochronous transfers function correctly
- **Test** actual USB capture throughput with each device

#### 2. `IOUSBInterfaceInterface300`
The code uses `IOUSBInterfaceInterface300` (USB 2.0 era interface). On Apple Silicon:
- All EasyCap devices are USB 2.0 (480 Mbps max)
- Apple Silicon Macs still support USB 2.0 via USB-A or USB-C adapters
- The `300` variant should still be available (backward compatible)

#### 3. Power management
Apple Silicon has stricter power management. USB devices may be suspended more aggressively. Ensure:
- Devices are properly woken before starting transfers
- Error handling for `kIOReturnNotResponding` (device suspended)

#### 4. Driver extensions
Apple has been pushing toward DriverKit (user-space drivers) instead of IOKit kernel extensions. For a **consumer application** (not a kernel extension), this should not be an issue — IOKit user-space client APIs are still available.

---

## 6.3 Changes Required

### 6.3.1 Audit all IOKit usage
Search for:
```
grep -r "IOService\|IOUSB\|IOKit\|IOUSBLowLatency\|IOCreatePlugInInterface\|IOUSBInterface" --include="*.h" --include="*.m"
```

Review each usage for:
- Correct API availability (no deprecated IOKit USB APIs)
- Proper error handling
- Memory management (ARC compatible)

### 6.3.2 Check `ECVController.m` device discovery
The device discovery in `ECVController.m` uses:
```objc
IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator)
```

**Potential issue:** `kIOMasterPortDefault` was deprecated in macOS 12.0, replaced by `kIOMainPortDefault`.

**Fix:**
```objc
// BEFORE (deprecated):
IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator);

// AFTER:
IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator);
```

Or better, use `IOMainPort(0, &mainPort)` for more explicit control.

### 6.3.3 USB interface interface version
Check if `IOUSBInterfaceInterface300` should be upgraded to a newer version. Options:
- `IOUSBInterfaceInterface` (generic, latest)
- `IOUSBInterfaceInterface300` (USB 2.0 specific)
- `IOUSBInterfaceInterface500` (USB 3.0 specific)

Since all devices are USB 2.0, `300` should be fine, but using the generic `IOUSBInterfaceInterface` may provide better compatibility.

### 6.3.4 Firmware upload (Somagic)
`ECVSomagicDevice.m` uploads firmware at initialization. This is a multi-step USB control transfer sequence. Verify:
- Control transfers work the same on Apple Silicon
- Timing requirements are met (some firmware uploads have strict timing)

---

## 6.4 Device-Specific Notes

### STK1160
- Uses `stk11xx.h` helper functions for register read/write
- `stk11xx-dev-0408.m` has device-specific initialization sequences
- Should work with no changes beyond ARC conversion

### EM2860
- Uses GPIO for device control
- Has both video (isoc) and audio (bulk) endpoints
- Audio bulk pipe uses `IOUSBPipe` — verify on Apple Silicon

### Somagic
- Most complex driver — firmware upload at init
- Firmware is stored as a byte array in `ECVSomagicDevice_Unloaded.m`
- Verify firmware upload completes correctly

### Fushicai
- Simplest driver
- NTSC/PAL mode switching via USB control transfer
- Should work with no issues

---

## 6.5 Testing Strategy

Each device needs **physical hardware testing** on Apple Silicon:

| Test | What to verify |
|------|----------------|
| Device enumeration | `IOServiceGetMatchingServices` finds the device |
| Interface opening | `IOUSBInterfaceInterface` opens successfully |
| Endpoint discovery | Video and audio endpoints found |
| Isochronous transfer | Video frames arrive at expected rate |
| Bulk transfer (audio) | Audio data arrives without drops |
| Error recovery | Device disconnect/reconnect handled gracefully |
| Power management | Device survives sleep/wake cycles |
| Multiple devices | Two capture devices can run simultaneously |

---

## 6.6 Verification

After Phase 6, the project should:
- [ ] `kIOMasterPortDefault` replaced with `kIOMainPortDefault`
- [ ] All IOKit USB usage compiles without warnings
- [ ] ARC-compatible memory management in all USB code
- [ ] STK1160 device captures video correctly on Apple Silicon
- [ ] EM2860 device captures video + audio correctly on Apple Silicon
- [ ] Somagic device firmware uploads correctly on Apple Silicon
- [ ] Fushicai device captures video correctly on Apple Silicon
- [ ] Device disconnect/reconnect works
- [ ] Sleep/wake with device connected works
