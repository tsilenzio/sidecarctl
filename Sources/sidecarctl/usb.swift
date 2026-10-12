// Whether an iPad is attached by cable, which SidecarCore does not report: a
// SidecarDevice carries no sign of the transports it can be reached over.

import Foundation
import IOKit

// Apple's USB vendor ID
let appleVendorID = 0x05AC

func iPadOnUSB() -> Bool {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator) == KERN_SUCCESS else {
        return false
    }
    defer { IOObjectRelease(iterator) }
    var found = false
    while case let service = IOIteratorNext(iterator), service != 0 {
        defer { IOObjectRelease(service) }
        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        if (property("idVendor") as? NSNumber)?.intValue == appleVendorID,
           (property("USB Product Name") as? String)?.contains("iPad") == true {
            found = true
        }
    }
    return found
}
