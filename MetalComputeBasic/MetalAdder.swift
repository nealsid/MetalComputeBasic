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

    func sendComputeCommand() {
        let commandBuffer = _mCommandQueue.makeCommandBuffer()!
        
        var fillEncoder = commandBuffer.makeComputeCommandEncoder()!
        encodeFillCommandsInEncoder(fillEncoder, toDestBuffer: _mBufferA)
        fillEncoder.endEncoding()
        
        fillEncoder = commandBuffer.makeComputeCommandEncoder()!
        encodeFillCommandsInEncoder(fillEncoder, toDestBuffer: _mBufferB)
        fillEncoder.endEncoding()
        
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        encodeAddCommandInEncoder(computeEncoder)
        computeEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        verifyResults()
    }
    
    func threadGroupSizeForPipeline(_ function : MTLComputePipelineState) -> MTLSize {
        return MTLSizeMake(min(function.maxTotalThreadsPerThreadgroup, _mArrayLength), 1, 1)
    }
    
    func encodeFillCommandsInEncoder(_ fillEncoder : MTLComputeCommandEncoder, toDestBuffer buffer : MTLBuffer) {
        fillEncoder.setComputePipelineState(_mFillFunctionPSO)
        fillEncoder.setBuffer(buffer, offset: 0, index: 0)

        fillEncoder.dispatchThreads(_mGridSize, threadsPerThreadgroup: threadGroupSizeForPipeline(_mFillFunctionPSO))
    }
    
    func encodeAddCommandInEncoder(_ computeEncoder : MTLComputeCommandEncoder) {
        computeEncoder.setComputePipelineState(_mAddFunctionPSO)
        computeEncoder.setBuffer(_mBufferA, offset: 0, index: 0)
        computeEncoder.setBuffer(_mBufferB, offset: 0, index: 1)
        computeEncoder.setBuffer(_mBufferResult, offset: 0, index: 2)

        computeEncoder.dispatchThreads(_mGridSize, threadsPerThreadgroup: threadGroupSizeForPipeline(_mAddFunctionPSO))
    }
    
    func verifyResults() {
        // Closure to create an unsafe buffer from an MTL Buffer, fixing both the length and that it's bound to floats.
        let createBuffer = { (x : MTLBuffer) -> UnsafeBufferPointer<Float> in
            UnsafeBufferPointer(start: x.contents().assumingMemoryBound(to: Float.self), count: self._mArrayLength)
            }
        
        let bufferA = createBuffer(_mBufferA)
        let bufferB = createBuffer(_mBufferB)
        let resultsBuffer = createBuffer(_mBufferResult)

        for ((i,a),(_,b)) in zip(bufferA.enumerated(), bufferB.enumerated()) {
            let f = resultsBuffer[i]
            if (f != a + b) {
                print("Compute FAILED: index=\(i1) result=\(f) vs \(a + b) = \(a) + \(b)")
            }
        }
    }
}
