import Foundation
@preconcurrency import Dispatch

/// Thread-safe mutable box for shared state
final class MutableBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    
    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
    
    init(_ value: T) {
        _value = value
    }
}

/// Service for executing shell commands with modern async/await patterns
actor ProcessService: ProcessExecutor {
    
    // MARK: - Process Execution Errors
    
    enum ProcessError: Error {
        case executionFailed(Int32)
        case outputEncodingFailed
        case processSetupFailed
        
        var localizedDescription: String {
            switch self {
            case .executionFailed(let code):
                return "Process execution failed with code \(code)"
            case .outputEncodingFailed:
                return "Failed to decode process output"
            case .processSetupFailed:
                return "Failed to set up process"
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Executes a shell command with arguments asynchronously
    /// - Parameters:
    ///   - command: The command to execute (full path)
    ///   - arguments: Command arguments
    ///   - timeout: Optional timeout in seconds
    /// - Returns: Command output as string
    /// - Throws: ProcessError if execution fails
    static func execute(command: String, arguments: [String] = [], timeout: TimeInterval = 10.0) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Set up timeout and completion tracking
            let hasResumedBox = MutableBox(false)
            let timeoutTask = DispatchWorkItem {
                if !hasResumedBox.value {
                    hasResumedBox.value = true
                    process.terminate()
                    continuation.resume(throwing: ProcessError.executionFailed(-1))
                }
            }
            
            process.terminationHandler = { process in
                timeoutTask.cancel()
                
                // Only resume if we haven't already resumed (handles race condition)
                if !hasResumedBox.value {
                    hasResumedBox.value = true
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    if process.terminationStatus == 0 {
                        if let output = String(data: outputData, encoding: .utf8) {
                            continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                        } else {
                            continuation.resume(throwing: ProcessError.outputEncodingFailed)
                        }
                    } else {
                        continuation.resume(throwing: ProcessError.executionFailed(process.terminationStatus))
                    }
                }
            }
            
            do {
                try process.run()
                // Schedule timeout
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutTask)
            } catch {
                if !hasResumedBox.value {
                    hasResumedBox.value = true
                    continuation.resume(throwing: ProcessError.processSetupFailed)
                }
            }
        }
    }
    
    /// Executes a shell script asynchronously
    /// - Parameters:
    ///   - script: Shell script content
    ///   - shell: Shell to use (default: /bin/sh)
    ///   - timeout: Optional timeout in seconds
    /// - Returns: Script output as string
    /// - Throws: ProcessError if execution fails
    static func executeScript(_ script: String, shell: String = "/bin/sh", timeout: TimeInterval = 10.0) async throws -> String {
        return try await execute(command: shell, arguments: ["-c", script], timeout: timeout)
    }
    
    /// Executes a command and returns success/failure without throwing
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Command arguments
    /// - Returns: Tuple of (success: Bool, output: String)
    static func executeSafely(command: String, arguments: [String] = []) async -> (success: Bool, output: String) {
        do {
            let output = try await execute(command: command, arguments: arguments)
            return (true, output)
        } catch {
            Logger.error("Command execution failed: \(error.localizedDescription)", category: "Process")
            return (false, error.localizedDescription)
        }
    }
}