//
//  SparkyDI.swift
//  KWh Gas Companion
//
//

// =============================================================
// FILE: SparkyDI.swift (simple dependency registry)
// =============================================================

import Foundation

@MainActor
public enum SparkyDI {
public static var store: SparkShiftStore = SparkShiftStore()
}
