//  EnergyEventStore.swift
//  My KWh Companion
//
//  Observes EntriesStore + TeslaFiSessionStore and publishes unified EnergyEvents.
//  Swift 6 • iOS 17+
//

import Foundation
import Combine

@MainActor
final class EnergyEventStore: ObservableObject {

    @Published private(set) var events: [EnergyEvent] = []
    @Published private(set) var links: [EnergyEventLink] = []

    private var cancellables = Set<AnyCancellable>()

    init(entriesStore: EntriesStore, teslaFiStore: TeslaFiSessionStore) {
        Publishers.CombineLatest(entriesStore.$entries, teslaFiStore.$sessions)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries, sessions in
                guard let self else { return }
                let built = EnergyEventBuilder.build(teslaFi: sessions, ledger: entries)
                self.events = built.events
                self.links = built.links
            }
            .store(in: &cancellables)
    }
}
