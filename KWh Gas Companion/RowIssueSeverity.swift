//
//  CSVRowValidator.swift
//  My KWh Companion
//
//  Inline row-level validation for the Map Columns step of CSVChargingWizardView.
//
//  Swift 6 / iOS 17+
//

import SwiftUI

// MARK: - Domain types

enum RowIssueSeverity: Comparable {
    case warning
    case error
}

struct RowIssue: Identifiable {
    let id = UUID()
    let rowIndex: Int
    let lineNumber: Int
    let column: String
    let rawValue: String
    let message: String
    let severity: RowIssueSeverity
}

struct ValidationSummary {
    let issues: [RowIssue]
    let errorCount: Int
    let warningCount: Int
    let affectedRowCount: Int

    var isEmpty: Bool { issues.isEmpty }
    var hasErrors: Bool { errorCount > 0 }

    var byRow: [(rowIndex: Int, lineNumber: Int, issues: [RowIssue])] {
        let grouped = Dictionary(grouping: issues, by: \.rowIndex)
        return grouped
            .sorted { $0.key < $1.key }
            .map { (rowIndex: $0.key,
                    lineNumber: $0.value.first!.lineNumber,
                    issues: $0.value) }
    }
}

// MARK: - Validator

enum CSVRowValidator {

    static func validate(
        rows: [[String]],
        mapping: ValidatorColumnMapping,
        maxIssues: Int = 200
    ) -> ValidationSummary {

        var issues: [RowIssue] = []

        for (rowIdx, row) in rows.enumerated() {
            guard issues.count < maxIssues else { break }
            let lineNo = rowIdx + 2

            func cell(_ idx: Int?) -> String? {
                guard let i = idx, i >= 0, i < row.count else { return nil }
                let v = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
                return v.isEmpty ? nil : v
            }

            // ChargeStartDateTime
            if let raw = cell(mapping.startDate) {
                if parseDate(raw) == nil {
                    issues.append(RowIssue(
                        rowIndex: rowIdx,
                        lineNumber: lineNo,
                        column: "ChargeStartDateTime",
                        rawValue: raw,
                        message: "Could not parse \"\(truncated(raw))\" as a date.",
                        severity: .error
                    ))
                }
            } else if mapping.startDate != nil {
                issues.append(RowIssue(
                    rowIndex: rowIdx,
                    lineNumber: lineNo,
                    column: "ChargeStartDateTime",
                    rawValue: "",
                    message: "Cell is empty -- row will be imported without a date.",
                    severity: .warning
                ))
            }

            // QuantityBase (kWh)
            if let raw = cell(mapping.energyAddedKWh) {
                if let kwh = parseDouble(raw) {
                    if kwh < 0 {
                        issues.append(RowIssue(
                            rowIndex: rowIdx,
                            lineNumber: lineNo,
                            column: "QuantityBase",
                            rawValue: raw,
                            message: "Negative kWh value (\(kwh)).",
                            severity: .warning
                        ))
                    } else if kwh > 250 {
                        issues.append(RowIssue(
                            rowIndex: rowIdx,
                            lineNumber: lineNo,
                            column: "QuantityBase",
                            rawValue: raw,
                            message: "\(kwh) kWh looks unusually high -- check column mapping.",
                            severity: .warning
                        ))
                    }
                } else {
                    issues.append(RowIssue(
                        rowIndex: rowIdx,
                        lineNumber: lineNo,
                        column: "QuantityBase",
                        rawValue: raw,
                        message: "Could not parse \"\(truncated(raw))\" as a number.",
                        severity: .error
                    ))
                }
            }

            // Total Inc. VAT
            if let raw = cell(mapping.totalIncVAT) {
                if let total = parseDouble(raw) {
                    if total < 0 {
                        issues.append(RowIssue(
                            rowIndex: rowIdx,
                            lineNumber: lineNo,
                            column: "Total Inc. VAT",
                            rawValue: raw,
                            message: "Negative total amount (\(total)).",
                            severity: .warning
                        ))
                    }
                } else {
                    issues.append(RowIssue(
                        rowIndex: rowIdx,
                        lineNumber: lineNo,
                        column: "Total Inc. VAT",
                        rawValue: raw,
                        message: "Could not parse \"\(truncated(raw))\" as a number.",
                        severity: .error
                    ))
                }
            }

            // UnitCostBase (Price/kWh)
            if let raw = cell(mapping.pricePerKWh) {
                if let price = parseDouble(raw) {
                    if price < 0 {
                        issues.append(RowIssue(
                            rowIndex: rowIdx,
                            lineNumber: lineNo,
                            column: "UnitCostBase",
                            rawValue: raw,
                            message: "Negative price per kWh (\(price)).",
                            severity: .warning
                        ))
                    } else if price > 5 {
                        issues.append(RowIssue(
                            rowIndex: rowIdx,
                            lineNumber: lineNo,
                            column: "UnitCostBase",
                            rawValue: raw,
                            message: "\(price)/kWh looks very high -- verify currency and column.",
                            severity: .warning
                        ))
                    }
                } else {
                    issues.append(RowIssue(
                        rowIndex: rowIdx,
                        lineNumber: lineNo,
                        column: "UnitCostBase",
                        rawValue: raw,
                        message: "Could not parse \"\(truncated(raw))\" as a number.",
                        severity: .error
                    ))
                }
            }

            // No amount source at all
            let hasInc     = cell(mapping.totalIncVAT).flatMap(parseDouble) != nil
            let hasExc     = cell(mapping.totalExcVAT).flatMap(parseDouble) != nil
            let hasDerived = cell(mapping.energyAddedKWh).flatMap(parseDouble) != nil
                          && cell(mapping.pricePerKWh).flatMap(parseDouble) != nil

            if !hasInc && !hasExc && !hasDerived {
                if mapping.totalIncVAT != nil || mapping.totalExcVAT != nil ||
                   (mapping.energyAddedKWh != nil && mapping.pricePerKWh != nil) {
                    issues.append(RowIssue(
                        rowIndex: rowIdx,
                        lineNumber: lineNo,
                        column: "Amount",
                        rawValue: "",
                        message: "No valid amount could be derived -- row will be skipped.",
                        severity: .error
                    ))
                }
            }
        }

        let errors   = issues.filter { $0.severity == .error }.count
        let warnings = issues.filter { $0.severity == .warning }.count
        let affected = Set(issues.map(\.rowIndex)).count

        return ValidationSummary(
            issues: issues,
            errorCount: errors,
            warningCount: warnings,
            affectedRowCount: affected
        )
    }

    // MARK: - Private parsers

    private static func parseDate(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if Double(t) != nil { return Date() }

        let iso1 = ISO8601DateFormatter()
        iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if iso1.date(from: t) != nil { return Date() }

        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        if iso2.date(from: t) != nil { return Date() }

        for fmt in [
            "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm",
            "M/d/yyyy H:mm", "M/d/yy H:mm",
            "MM/dd/yyyy HH:mm", "dd/MM/yyyy HH:mm"
        ] {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            if df.date(from: t) != nil { return Date() }
        }
        return nil
    }

    private static func parseDouble(_ s: String) -> Double? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: "kwh", with: "", options: .caseInsensitive)
             .replacingOccurrences(of: "$", with: "")
             .replacingOccurrences(of: "\u{20AC}", with: "")
             .replacingOccurrences(of: "\u{00A3}", with: "")
        let hasComma = t.contains(",")
        let hasDot   = t.contains(".")
        if hasComma && hasDot {
            if let lc = t.lastIndex(of: ","), let ld = t.lastIndex(of: ".") {
                t = lc > ld
                    ? t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                    : t.replacingOccurrences(of: ",", with: "")
            }
        } else if hasComma {
            t = t.replacingOccurrences(of: ",", with: ".")
        }
        let allowed = CharacterSet(charactersIn: "+-0123456789.eE")
        t = String(t.unicodeScalars.filter { allowed.contains($0) })
        return Double(t)
    }

    private static func truncated(_ s: String, limit: Int = 24) -> String {
        s.count > limit ? String(s.prefix(limit)) + "..." : s
    }
}

// MARK: - ValidatorColumnMapping

struct ValidatorColumnMapping {
    var startDate: Int?
    var energyAddedKWh: Int?
    var pricePerKWh: Int?
    var totalIncVAT: Int?
    var totalExcVAT: Int?
    var vatAmount: Int?
}

// MARK: - MappingValidationBanner

struct MappingValidationBanner: View {
    let summary: ValidationSummary
    @State private var expanded = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if summary.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: summary.hasErrors
                              ? "exclamationmark.triangle.fill"
                              : "exclamationmark.circle.fill")
                            .foregroundStyle(summary.hasErrors ? .red : .orange)
                            .imageScale(.medium)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(headlineText)
                                .font(.subheadline.weight(.semibold))
                            Text("Tap to review affected rows before importing.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)

                if expanded {
                    Divider().padding(.horizontal, 14)
                    RowIssueList(summary: summary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        summary.hasErrors
                        ? Color.red.opacity(scheme == .dark ? 0.12 : 0.07)
                        : Color.orange.opacity(scheme == .dark ? 0.12 : 0.07)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                summary.hasErrors
                                ? Color.red.opacity(0.22)
                                : Color.orange.opacity(0.22),
                                lineWidth: 1
                            )
                    )
            )
        }
    }

    private var headlineText: String {
        var parts: [String] = []
        if summary.errorCount > 0 {
            parts.append("\(summary.errorCount) error\(summary.errorCount == 1 ? "" : "s")")
        }
        if summary.warningCount > 0 {
            parts.append("\(summary.warningCount) warning\(summary.warningCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ") + " found in \(summary.affectedRowCount) row\(summary.affectedRowCount == 1 ? "" : "s")"
    }
}

// MARK: - RowIssueList

struct RowIssueList: View {
    let summary: ValidationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(summary.byRow.prefix(30), id: \.rowIndex) { group in
                VStack(alignment: .leading, spacing: 5) {
                    Text("Line \(group.lineNumber)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    ForEach(group.issues) { issue in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: issue.severity == .error
                                  ? "xmark.circle.fill"
                                  : "exclamationmark.circle.fill")
                                .foregroundStyle(issue.severity == .error ? .red : .orange)
                                .font(.caption)
                                .padding(.top, 1)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.column)
                                    .font(.caption.weight(.semibold))
                                Text(issue.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                if group.rowIndex != summary.byRow.prefix(30).last?.rowIndex {
                    Divider()
                }
            }

            if summary.affectedRowCount > 30 {
                Text("... and \(summary.affectedRowCount - 30) more rows with issues.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Validation Banner") {
    let issues: [RowIssue] = [
        RowIssue(
            rowIndex: 0, lineNumber: 2,
            column: "ChargeStartDateTime",
            rawValue: "not-a-date",
            message: "Could not parse \"not-a-date\" as a date.",
            severity: .error
        ),
        RowIssue(
            rowIndex: 1, lineNumber: 3,
            column: "QuantityBase",
            rawValue: "abc",
            message: "Could not parse \"abc\" as a number.",
            severity: .error
        ),
        RowIssue(
            rowIndex: 2, lineNumber: 4,
            column: "UnitCostBase",
            rawValue: "999",
            message: "999/kWh looks very high -- verify currency and column.",
            severity: .warning
        ),
    ]
    let summary = ValidationSummary(
        issues: issues, errorCount: 2, warningCount: 1, affectedRowCount: 3
    )
    return MappingValidationBanner(summary: summary)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
#endif
