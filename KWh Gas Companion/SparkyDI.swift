//
//  SparkyDI.swift
//  KWh Gas Companion
//
//  Created by Bryan on 10/27/25.
//




// =============================================================
// FILE: SparkyDI.swift (simple dependency registry)
// =============================================================


import Foundation


@MainActor
public enum SparkyDI {
public static var store: SparkShiftStore = SparkShiftStore()
}
