//
//  atomics-reference.swift
//  Atomics
//
//  Created by Guillaume Lessard on 1/16/17.
//  Copyright © 2017 Guillaume Lessard. All rights reserved.
//  This file is distributed under the BSD 3-clause license. See LICENSE for details.
//

@_exported import enum CAtomics.MemoryOrder
@_exported import enum CAtomics.LoadMemoryOrder
@_exported import enum CAtomics.StoreMemoryOrder
import CAtomics

import struct CAtomics.OpaqueUnmanagedHelper

#if !swift(>=3.2)
extension MemoryOrder
{
  @_versioned init(order: LoadMemoryOrder)
  {
    self = MemoryOrder.init(rawValue: order.rawValue) ?? .sequential
  }

  @_versioned init(order: StoreMemoryOrder)
  {
    self = MemoryOrder.init(rawValue: order.rawValue) ?? .sequential
  }
}
#endif

public struct AtomicReference<T: AnyObject>
{
#if swift(>=4.2)
  @usableFromInline internal var ptr = OpaqueUnmanagedHelper()
#else
  @_versioned internal var ptr = OpaqueUnmanagedHelper()
#endif

  public init(_ reference: T? = nil)
  {
    self.initialize(reference)
  }

  mutating public func initialize(_ reference: T?)
  {
    let u = reference.map { Unmanaged.passRetained($0).toOpaque() }
    CAtomicsInitialize(&ptr, u)
  }
}

extension AtomicReference
{
#if swift(>=4.2)
  @inlinable
  public mutating func swap(_ reference: T?, order: MemoryOrder = .acqrel) -> T?
  {
    let u = reference.map { Unmanaged.passRetained($0).toOpaque() }

    let pointer = CAtomicsExchange(&ptr, u, order)
    return pointer.map { Unmanaged.fromOpaque($0).takeRetainedValue() }
  }
#else
  @inline(__always)
  public mutating func swap(_ reference: T?, order: MemoryOrder = .acqrel) -> T?
  {
    let u = reference.map { Unmanaged.passRetained($0).toOpaque() }

    let pointer = CAtomicsExchange(&ptr, u, order)
    return pointer.map { Unmanaged.fromOpaque($0).takeRetainedValue() }
  }
#endif

#if swift(>=5.0)
  @available(swift, obsoleted: 5.0, renamed: "storeIfNil(_:order:)")
  public mutating func swapIfNil(_ ref: T, order: MemoryOrder = .sequential) -> Bool { fatalError() }
#else
  @available(*, deprecated, renamed: "storeIfNil(_:order:)")
  public mutating func swapIfNil(_ ref: T, order: StoreMemoryOrder = .sequential) -> Bool
  {
    return self.storeIfNil(ref, order: order)
  }
#endif

#if swift(>=4.2)
  @inlinable
  public mutating func storeIfNil(_ reference: T, order: StoreMemoryOrder = .release) -> Bool
  {
    let u = Unmanaged.passRetained(reference)
    if CAtomicsCompareAndExchange(&ptr, nil, u.toOpaque(), .strong, MemoryOrder(rawValue: order.rawValue)!)
    { return true }

    u.release()
    return false
  }
#elseif swift(>=3.2)
  @inline(__always)
  public mutating func storeIfNil(_ reference: T, order: StoreMemoryOrder = .release) -> Bool
  {
    let u = Unmanaged.passRetained(reference)
    if CAtomicsCompareAndExchange(&ptr, nil, u.toOpaque(), .strong, MemoryOrder(rawValue: order.rawValue)!)
    { return true }

    u.release()
    return false
  }
#else
  @inline(__always)
  public mutating func storeIfNil(_ reference: T, order: StoreMemoryOrder = .sequential) -> Bool
  {
    let u = Unmanaged.passRetained(reference)
    if CAtomicsCompareAndExchange(&ptr, nil, u.toOpaque(), .strong, MemoryOrder(order: order))
    { return true }

    u.release()
    return false
  }
#endif

#if swift(>=4.2)
  @inlinable
  public mutating func take(order: LoadMemoryOrder = .acquire) -> T?
  {
    let pointer = CAtomicsExchange(&ptr, nil, MemoryOrder(rawValue: order.rawValue)!)
    return pointer.map { Unmanaged.fromOpaque($0).takeRetainedValue() }
  }
#elseif swift(>=3.2)
  @inline(__always)
  public mutating func take(order: LoadMemoryOrder = .acquire) -> T?
  {
    let pointer = CAtomicsExchange(&ptr, nil, MemoryOrder(rawValue: order.rawValue)!)
    return pointer.map { Unmanaged.fromOpaque($0).takeRetainedValue() }
  }
#else // swift 3.1
  @inline(__always)
  public mutating func take(order: LoadMemoryOrder = .sequential) -> T?
  {
    let pointer = CAtomicsExchange(&ptr, nil, MemoryOrder(order: order))
    return pointer.map { Unmanaged.fromOpaque($0).takeRetainedValue() }
  }
#endif
    
#if swift(>=4.2)
  @inlinable @discardableResult
  public mutating func CAS(current: T?, future: T?,
                           order: MemoryOrder = .acqrel) -> Bool
  {
    let c = current.map(Unmanaged.passUnretained)
    let f = future.map(Unmanaged.passRetained)

    if CAtomicsCompareAndExchangeStrong(&ptr, c?.toOpaque(), f?.toOpaque(), order)
    {
      c?.release()
      return true
    }

    f?.release()
    return false
  }
#else
  @inline(__always) @discardableResult
  public mutating func CAS(current: T?, future: T?,
                           order: MemoryOrder = .acqrel) -> Bool
  {
    let c = current.map(Unmanaged.passUnretained)
    let f = future.map(Unmanaged.passRetained)

    if CAtomicsCompareAndExchangeStrong(&ptr, c?.toOpaque(), f?.toOpaque(), order)
    {
      c?.release()
      return true
    }

    f?.release()
    return false
  }
#endif

  @available(*, deprecated, renamed: "CAS(current:future:order:)")
  public mutating func CAS(current: T?, future: T?, type: CASType, order: MemoryOrder = .acqrel) -> Bool
  {
    return CAS(current: current, future: future, order: order)
  }
}
