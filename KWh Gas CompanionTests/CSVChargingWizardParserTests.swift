import Testing
@testable import KWh_Gas_Companion

struct CSVChargingWizardParserTests {
    @Test
    func quotedLineBreakStaysInsideTeslaDescription() {
        let csv = """
        ChargeStartDateTime,QuantityBase,Total Inc. VAT,Description
        2026-05-01 12:00,42.5,18.50,"Supercharger session
        idle fee waived"
        """

        let parsed = CSVParser.parse(csv)

        #expect(parsed.headers.count == 4)
        #expect(parsed.rows.count == 1)
        #expect(parsed.rows[0].count == 4)
        #expect(parsed.rows[0][3] == "Supercharger session\nidle fee waived")
    }

    @Test
    func shortRowsArePaddedToMappedHeaderWidth() {
        let rows = [
            ["2026-05-01 12:00", "42.5", "18.50"],
            ["2026-05-02 12:00"]
        ]

        let padded = OfficialTeslaCSVRowShape.paddedRows(rows, headerCount: 3)

        #expect(padded[0].count == 3)
        #expect(padded[1].count == 3)
        #expect(padded[1][1].isEmpty)
        #expect(padded[1][2].isEmpty)
    }
}
