//
//  MetalAdder.swift
//  MetalComputeBasic
//
//  Created by Neal Sidhwaney on 8/31/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation
import Metal

class MetalAdder {
    let _mArrayLength : Int = 1 << 24;
    let _mBufferSize : Int
    
    let _mDevice : MTLDevice
    
    let _mAddFunctionPSO : MTLComputePipelineState
    let _mFillFunctionPSO : MTLComputePipelineState
    
    let _mCommandQueue : MTLCommandQueue
    let _mBufferA, _mBufferB, _mBufferResult : MTLBuffer

    let _mGridSize : MTLSize

    init(device : MTLDevice) {
        self._mDevice = device
        _mBufferSize = _mArrayLength * MemoryLayout<Float>.size // sizeof float
        let defaultLibrary = _mDevice.makeDefaultLibrary()!
        let addFunction = defaultLibrary.makeFunction(name: "add_arrays")!
        let fillArray = defaultLibrary.makeFunction(name: "fill_array")!
        _mGridSize = MTLSizeMake(_mArrayLength, 1, 1)
        
        _mAddFunctionPSO = try! _mDevice.makeComputePipelineState(function: addFunction)
        
        _mFillFunctionPSO = try! _mDevice.makeComputePipelineState(function: fillArray)
        
        _mCommandQueue = _mDevice.makeCommandQueue()!
        
        _mBufferA = _mDevice.makeBuffer(length: _mBufferSize, options: MTLResourceOptions.storageModeShared)!
        _mBufferB = _mDevice.makeBuffer(length: _mBufferSize, options: MTLResourceOptions.storageModeShared)!
        _mBufferResult = _mDevice.makeBuffer(length: _mBufferSize, options: MTLResourceOptions.storageModeShared)!
    }
    
    func generateRandomFloatData (buffer : MTLBuffer) {
        let bPtr = buffer.contents()
        for i in 0..<_mArrayLength {
            bPtr.storeBytes(of: Float.random(in: 0...1), toByteOffset: i * 4, as: Float.self)
        }
    }
    
    func sendComputeCommand() {
        let commandBuffer = _mCommandQueue.makeCommandBuffer()!
        
        var fillEncoder = commandBuffer.makeComputeCommandEncoder()!
        encodeFillCommands(fillEncoder, buffer: _mBufferA)
        fillEncoder.endEncoding()
        
        fillEncoder = commandBuffer.makeComputeCommandEncoder()!
        encodeFillCommands(fillEncoder, buffer: _mBufferB)
        fillEncoder.endEncoding()
        
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        encodeAddCommand(computeEncoder)
        computeEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        verifyResults()
    }
    
    func encodeFillCommands(_ fillEncoder : MTLComputeCommandEncoder, buffer : MTLBuffer) {
        fillEncoder.setComputePipelineState(_mFillFunctionPSO)
        fillEncoder.setBuffer(buffer, offset: 0, index: 0)

        let mtlThreadGroupSize = MTLSizeMake(min(_mFillFunctionPSO.maxTotalThreadsPerThreadgroup, _mArrayLength), 1, 1)
        fillEncoder.dispatchThreads(_mGridSize, threadsPerThreadgroup: mtlThreadGroupSize)
    }
    
    func encodeAddCommand(_ computeEncoder : MTLComputeCommandEncoder) {
        computeEncoder.setComputePipelineState(_mAddFunctionPSO)
        computeEncoder.setBuffer(_mBufferA, offset: 0, index: 0)
        computeEncoder.setBuffer(_mBufferB, offset: 0, index: 1)
        computeEncoder.setBuffer(_mBufferResult, offset: 0, index: 2)

        let mtlThreadGroupSize = MTLSizeMake(min(_mAddFunctionPSO.maxTotalThreadsPerThreadgroup, _mArrayLength), 1, 1)
        computeEncoder.dispatchThreads(_mGridSize, threadsPerThreadgroup: mtlThreadGroupSize)
    }
    
    func verifyResults() {
        let bufferA = UnsafeBufferPointer(start: _mBufferA.contents().assumingMemoryBound(to: Float.self), count: _mArrayLength)
        let bufferB = UnsafeBufferPointer(start: _mBufferB.contents().assumingMemoryBound(to: Float.self), count: _mArrayLength)
        let resultsBuffer = UnsafeBufferPointer(start: _mBufferResult.contents().assumingMemoryBound(to: Float.self), count: _mArrayLength)
        for ((i1,b1),(_,b2)) in zip(bufferA.enumerated(), bufferB.enumerated()) {
            let a = b1
            let b = b2
            let f = resultsBuffer[i1]
            print("Compute: index=\(i1) result=\(f) vs \(a + b) = \(a) + \(b)")
        }
    }
}
