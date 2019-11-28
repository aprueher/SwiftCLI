//
//  Parameter.swift
//  SwiftCLI
//
//  Created by Jake Heiser on 3/7/15.
//  Copyright (c) 2015 jakeheis. All rights reserved.
//

public protocol AnyParameter: AnyValueBox {
    var required: Bool { get }
    var satisfied: Bool { get }
}

public class _Param<Value: ConvertibleFromString> {
    
    public let completion: ShellCompletion
    public let validation: [Validation<Value>]
    
    /// Creates a new parameter
    ///
    /// - Parameter completion: the completion type for use in ZshCompletionGenerator; default .filename
    public init(completion: ShellCompletion = .filename, validation: [Validation<Value>] = []) {
        self.completion = completion
        self.validation = validation
    }
    
}

@propertyWrapper
public class Param<Value: ConvertibleFromString> : _Param<Value>, AnyParameter, ValueBox {
    
    public let required = true
    public var satisfied: Bool { privValue != nil }
    
    private var privValue: Value?
    public var wrappedValue: Value {
        guard let val = privValue else {
            fatalError("cannot access parameter value outside of 'execute' func")
        }
        return val
    }
    public var value: Value { wrappedValue }
    public var projectedValue: Param { self }
    
    public init() {
        super.init()
    }
    
    public override init(completion: ShellCompletion = .filename, validation: [Validation<Value>] = []) {
        super.init(completion: completion, validation: validation)
    }
    
    public init(completion: ShellCompletion = .filename, validation: Validation<Value>...) {
        super.init(completion: completion, validation: validation)
    }
    
    public func update(to value: Value) {
        self.privValue = value
    }
    
}
    
@propertyWrapper
public class OptParam<Value: ConvertibleFromString> : _Param<Value>, AnyParameter, ValueBox {
    
    public let required = false
    public var satisfied = true
    
    public private(set) var wrappedValue: Value?
    public var value: Value? { wrappedValue }
    public var projectedValue: OptParam { self }
    
    public init() {
        super.init()
    }
    
    public override init(completion: ShellCompletion = .filename, validation: [Validation<Value>] = []) {
        super.init(completion: completion, validation: validation)
    }
    
    public init(completion: ShellCompletion = .filename, validation: Validation<Value>...) {
        super.init(completion: completion, validation: validation)
    }
    
    public func update(to value: Value) {
        self.wrappedValue = value
    }
    
}

public protocol AnyCollectedParameter: AnyParameter {
    var minCount: Int { get }
}

@propertyWrapper
public class CollectedParam<Value: ConvertibleFromString> : _Param<Value>, AnyCollectedParameter, ValueBox {
    
    public var required: Bool { minCount > 0 }
    public var satisfied: Bool { value.count >= minCount }
    
    public private(set) var wrappedValue: [Value] = []
    public var value: [Value] { wrappedValue }
    public var projectedValue: CollectedParam {
        return self
    }
    
    public let minCount: Int
    
    public init() {
        self.minCount = 0
        super.init()
    }
    
    public init(minCount: Int = 0, completion: ShellCompletion = .filename, validation: [Validation<Value>] = []) {
        self.minCount = minCount
        super.init(completion: completion, validation: validation)
    }
    
    public init(minCount: Int = 0, completion: ShellCompletion = .filename, validation: Validation<Value>...) {
        self.minCount = minCount
        super.init(completion: completion, validation: validation)
    }
    
    public func update(to value: Value) {
        self.wrappedValue.append(value)
    }
    
}

// MARK: - NamedParameter

public struct NamedParameter {
    public let name: String
    public let param: AnyParameter
    
    public var signature: String {
        var sig = "<\(name)>"
        if param.required == false {
            sig = "[\(sig)]"
        }
        if param is AnyCollectedParameter {
            sig += " ..."
        }
        return sig
    }
    
    public init(name: String, param: AnyParameter) {
        self.name = name
        self.param = param
    }
}

// MARK: - ParameterIterator

public class ParameterIterator {
    
    private var params: [NamedParameter]
    private let collected: NamedParameter?
    
    public let minCount: Int
    public let maxCount: Int?
    
    public init(command: CommandPath) {
        var all = command.command.parameters
        
        assert(all.firstIndex(where: { !$0.param.required }) ?? all.endIndex >= all.filter({ $0.param.required }).count, "optional parameters must come after all required parameters")
        
        var minCount = 0
        
        if let last = all.last, let collected = last.param as? AnyCollectedParameter {
            all.removeLast()
            assert(!all.contains(where: { $0.param is AnyCollectedParameter }), "can only have one collected parameter")
            
            self.collected = last
            self.maxCount = nil
            minCount = collected.minCount
        } else {
            assert(!all.contains(where: { $0.param is AnyCollectedParameter }), "the collected parameter must be the last parameter")
            self.collected = nil
            self.maxCount = all.count
        }
        
        self.minCount = all.filter({ $0.param.required }).count + minCount
        self.params = all
    }
    
    public func nextIsCollection() -> Bool {
        return params.isEmpty && collected != nil
    }

    public func next() -> NamedParameter? {
        if let individual = params.first {
            params.removeFirst()
            return individual
        }
        return collected
    }
    
}

