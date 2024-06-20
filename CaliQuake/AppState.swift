//
//  AppState.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/19/24.
//

import Foundation
import SwiftData

@Model
final class AppState {
    public var childpty: pid_t
    
    init(child: pid_t) {
        self.childpty = child
    }
}
