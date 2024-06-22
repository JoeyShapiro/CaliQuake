//
//  InnerView.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/21/24.
//

import SwiftUI

struct InnerView: View {
    var body: some View {
        Rectangle()
            .frame(width: 500, height: 500)
            .foregroundColor(Color.black.opacity(0.001))
            .onTapGesture { location in
#if DEBUG
#endif
            }
    }
}
