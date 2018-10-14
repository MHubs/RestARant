//
//  Information.swift
//  RestARant
//
//  Created by Maxwell Hubbard on 10/13/18.
//  Copyright © 2018 Maxwell Hubbard. All rights reserved.
//

import Foundation
import SceneKit

class Information {
    
    var calories: Double = 0
    var ingredients: [String] = []
    var scale: SCNVector3 = SCNVector3(1, 1, 1)
    
    var nutrients: [String: String] = [:]
}
