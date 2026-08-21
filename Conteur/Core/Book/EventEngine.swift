import Foundation

struct EventEngine: Sendable {
    func events(from session: SessionSnapshot, in book: BookSession) -> [BookEvent] {
        var events: [BookEvent] = []

        for beat in session.beats {
            for entity in beat.entitiesIntroduced {
                events.append(
                    BookEvent(
                        sessionNumber: session.number,
                        timestamp: beat.start,
                        kind: .entityIntroduced,
                        subject: entity,
                        detailText: beat.summary,
                        evidenceStart: beat.start
                    )
                )
            }
            for entity in beat.entitiesReferenced {
                events.append(
                    BookEvent(
                        sessionNumber: session.number,
                        timestamp: beat.start,
                        kind: .entityReferenced,
                        subject: entity,
                        detailText: beat.summary,
                        evidenceStart: beat.start
                    )
                )
            }
        }

        for component in session.arc.present {
            events.append(
                BookEvent(
                    sessionNumber: session.number,
                    timestamp: session.startTime,
                    kind: .componentCovered,
                    subject: component.rawValue,
                    detailText: "component covered in session \(session.number)",
                    evidenceStart: session.startTime
                )
            )
        }

        if session.beats.contains(where: \.statesStakes) {
            events.append(
                BookEvent(
                    sessionNumber: session.number,
                    timestamp: session.startTime,
                    kind: .stakesStated,
                    subject: "stakes",
                    detailText: "stakes were stated in session \(session.number)",
                    evidenceStart: session.startTime
                )
            )
        }

        events.append(contentsOf: session.emotionEvents.map { emotion in
            BookEvent(
                sessionNumber: session.number,
                timestamp: emotion.beatStart,
                kind: emotion.result.eventKind,
                subject: emotion.expected.rawValue,
                detailText: emotion.description,
                evidenceStart: emotion.beatStart
            )
        })
        return events
    }

    func targetedContext(for session: SessionSnapshot, in book: BookSession) -> TargetedContext {
        let mentioned = session.beats.flatMap(\.entitiesReferenced)
        let hasEmotionalBeats = session.beats.contains { $0.kind == .emotional }

        return TargetedContext(
            bookTitle: book.title,
            evaluationMode: session.mode,
            entityEvents: book.events
                .matching(kinds: [.entityIntroduced, .entityReferenced])
                .matching(subjects: mentioned)
                .sorted { $0.timestamp < $1.timestamp }
                .prefix(10)
                .map { $0 },
            emotionalHistory: hasEmotionalBeats
                ? Array(
                    book.events
                        .matching(kinds: [.emotionalMatch, .emotionalMismatch, .emotionalAdjacent])
                        .inLast(sessions: book.lastSessionNumber - 1)
                        .prefix(6)
                )
                : [],
            stakesEvent: book.events
                .filter { $0.kind == .stakesStated }
                .sorted { $0.timestamp > $1.timestamp }
                .first,
            componentEvents: book.events
                .matching(kind: .componentCovered)
                .matching(subjects: session.arc.missing.map(\.rawValue))
        )
    }

    func updateEntityRegistry(from session: SessionSnapshot, into book: inout [EntityRecord]) {
        for beat in session.beats {
            for entity in beat.entitiesIntroduced {
                if !book.contains(where: { $0.name == entity }) {
                    book.append(
                        EntityRecord(
                            name: entity,
                            introducedInSession: session.number,
                            firstAppearanceDescription: beat.summary,
                            lastMentionedSession: session.number
                        )
                    )
                }
            }
            for entity in beat.entitiesReferenced {
                if let index = book.firstIndex(where: { $0.name == entity }) {
                    var record = book[index]
                    record.lastMentionedSession = session.number
                    record.mentionCount += 1
                    if let emotion = session.emotionFor(entity) {
                        record.emotionalAssociations.append(
                            EmotionAssociation(session: session.number, emotion: emotion, context: beat.summary)
                        )
                    }
                    book[index] = record
                }
            }
        }
    }
}

struct SessionSnapshot: Sendable {
    let number: Int
    let startTime: TimeInterval
    let mode: ChallengeMode
    let beats: [Beat]
    let arc: NarrativeArc
    let emotionEvents: [EmotionMatch]
    let emotionMap: [String: DetectedEmotion]

    func emotionFor(_ entity: String) -> DetectedEmotion? {
        emotionMap[entity]
    }
}

private extension Array where Element == BookEvent {
    func matching(kinds: [EventKind]) -> Self {
        filter { kinds.contains($0.kind) }
    }

    func matching(kind: EventKind) -> Self {
        filter { $0.kind == kind }
    }

    func matching(subjects: [String]) -> Self {
        filter { subjects.contains($0.subject) }
    }

    func inLast(sessions: Int) -> Self {
        guard sessions > 0 else { return [] }
        return filter { $0.sessionNumber >= sessions }
    }
}
