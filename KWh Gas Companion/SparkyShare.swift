//
//  SparkyShare.swift
//  KWh Gas Companion
//
//  Created by Bryan on 10/27/25.
//




// =============================================================
// FILE: SparkyShare.swift (optional shareable image helper)
// =============================================================


import UIKit


public enum SparkyShare {
public static func makeTripBadge(from s: SparkShiftEntry, scale: CGFloat = 3, locale: Locale = .current) -> UIImage {
let size = CGSize(width: 320, height: 400)
let format = UIGraphicsImageRendererFormat(); format.scale = scale
return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
let r = CGRect(origin: .zero, size: size)
UIColor.systemBackground.setFill(); ctx.fill(r)


let title = "\(s.kind?.emoji ?? "⚡️") \(s.site ?? "Session")"
title.draw(in: CGRect(x: 20, y: 24, width: 280, height: 28), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])


let kWh = s.energyKWh ?? 0
let mi = s.miles ?? 0
let whmi = (mi > 0 && kWh > 0) ? Int((kWh * 1000) / mi) : 0
let cost = s.cost ?? 0


let nf = NumberFormatter(); nf.locale = locale; nf.minimumFractionDigits = 1; nf.maximumFractionDigits = 1
let kwhStr = nf.string(from: kWh as NSNumber) ?? "0.0"
let miStr = nf.string(from: mi as NSNumber) ?? "0.0"


let stats = "⚡️ \(kwhStr) kWh\n🛣️ \(miStr) mi\n🔢 \(whmi) Wh/mi\n💵 \(currency(cost, locale))"
stats.draw(in: CGRect(x: 20, y: 72, width: 280, height: 220), withAttributes: [.font: UIFont.systemFont(ofSize: 16)])


("My KWh Companion • Sparky").draw(in: CGRect(x: 20, y: 350, width: 280, height: 24), withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
}
}


private static func currency(_ value: Double, _ locale: Locale) -> String {
let nf = NumberFormatter(); nf.locale = locale; nf.numberStyle = .currency
return nf.string(from: value as NSNumber) ?? String(format: "$%.2f", value)
}
}