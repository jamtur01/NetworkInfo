//
//  Version.swift
//  NetworkInfo
//
//  Created by James Turnbull
//

import Foundation

/// Version information for the NetworkInfo app
public struct Version {
    /// The current version of the app
    public static let version = "1.0.0"
    
    /// The current build number
    public static let build = "1"
    
    /// The full version string (version + build)
    public static let fullVersion = "\(version) (\(build))"
}