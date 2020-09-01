//
//  main.swift
//  MetalComputeBasic
//
//  Created by Neal Sidhwaney on 8/31/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation
import Metal

var device = MTLCreateSystemDefaultDevice()!

var adder = MetalAdder(device: device)

adder.sendComputeCommand()

