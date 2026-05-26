import Foundation

public enum ConfigurationDirectoryRelocationMode: Equatable {
    /// Target has no business YAML; copy files from the old directory.
    case copyCurrentToEmptyTarget
    /// Target already has YAML; validate, keep target files, merge missing from old.
    case adoptTargetAndMergeMissing
}
