// RepeatingExpenseMaterializer.swift
import Foundation

/// Expand repeating entries into dated instances for a given window.
/// - Parameters:
///   - base: source array (may include non-repeating and repeating templates)
///   - windowStart / windowEnd: inclusive range to expand into
/// - Returns: materialized entries (original non-repeating + clones of repeat templates)
func materializedEntries(
    from base: [ExpenseEntry],
    windowStart: Date,
    windowEnd: Date,
    calendar: Calendar = .current
) -> [ExpenseEntry] {

    var out: [ExpenseEntry] = []
    out.reserveCapacity(base.count * 2)

    for e in base {
        guard let rule = e.repeatRule else {
            out.append(e)          // non-repeating: keep as-is
            continue
        }

        // Expand occurrences
        let dates = RepeatEngine.expand(from: windowStart, to: windowEnd, rule: rule, calendar: calendar)

        // For each occurrence date, create a cloned entry with the shifted date/time.
        for occ in dates {
            // If the original is the template at startDate, include it once (no duplicates)
            if calendar.isDate(occ, inSameDayAs: e.date) {
                // Ensure the displayed time equals the original's time (most UIs sort by date directly)
                var keep = e
                keep.date = occ
                out.append(keep)
                continue
            }

            var clone = e
            clone.id = UUID()            // new identity
            clone.date = occ             // place on occurrence date

            // If you want to shift nested charge start/end by the same (date-only) delta, keep the time:
            if var ch = clone.charging {
                if let s = ch.startDate {
                    let t = calendar.dateComponents([.hour, .minute, .second], from: s)
                    ch.startDate = calendar.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: t.second ?? 0, of: occ)
                }
                if let e = ch.endDate {
                    let t = calendar.dateComponents([.hour, .minute, .second], from: e)
                    ch.endDate = calendar.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: t.second ?? 0, of: occ)
                }
                clone.charging = ch
            }

            // Optionally, annotate invoice number to avoid collisions (comment out if undesired)
            // if let inv = clone.invoiceNumber {
            //     let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
            //     clone.invoiceNumber = "\(inv)-\(df.string(from: occ))"
            // }

            out.append(clone)
        }
    }

    return out
}
