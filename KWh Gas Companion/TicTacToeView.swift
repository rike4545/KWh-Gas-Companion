import SwiftUI

struct TicTacToeView: View {
    @State private var cells = Array(repeating: "", count: 9)
    @State private var currentPlayer = "X"

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 18) {
            Text(status)
                .font(.title3.weight(.semibold))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cells.indices, id: \.self) { index in
                    Button {
                        play(index)
                    } label: {
                        Text(cells[index].isEmpty ? " " : cells[index])
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!cells[index].isEmpty || winner != nil)
                    .accessibilityLabel("Cell \(index + 1)")
                }
            }

            Button("Reset Game", action: reset)
                .buttonStyle(.borderedProminent)

            Text("A small local game for parked or charging downtime. It never connects to Tesla, TeslaFi, or a vehicle control API.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .navigationTitle("Tic Tac Toe")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var status: String {
        if let winner { return "\(winner) wins" }
        if cells.allSatisfy({ !$0.isEmpty }) { return "Draw" }
        return "\(currentPlayer) turn"
    }

    private var winner: String? {
        let wins = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]
        return wins.compactMap { line in
            let mark = cells[line[0]]
            return !mark.isEmpty && line.allSatisfy { cells[$0] == mark } ? mark : nil
        }.first
    }

    private func play(_ index: Int) {
        guard cells[index].isEmpty, winner == nil else { return }
        cells[index] = currentPlayer
        currentPlayer = currentPlayer == "X" ? "O" : "X"
    }

    private func reset() {
        cells = Array(repeating: "", count: 9)
        currentPlayer = "X"
    }
}
