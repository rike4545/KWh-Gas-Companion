import SwiftUI

@MainActor
public struct ExpensesTabRoot: View {
    public init() {}

    public var body: some View {
        // ExpenseListTabView already manages its own NavigationStack
        ExpenseListTabView()
    }
}
