import Foundation

/// The stories the app gives you to read.
///
/// Written and annotated by hand rather than generated on the device. Two reasons: a 3B
/// model's prose is competent and forgettable, and nobody wants to retell a story that
/// bored them; and the annotation has to be *exact* to be worth having — an authored beat
/// sheet is ground truth, whereas one the model claims about its own output is another
/// inference.
///
/// Kept as Swift rather than bundled JSON so the ground truth is checked by the compiler.
enum StoryLibrary {
    static let all: [GuidedStory] = [thirdCast, whatTheHouseKept, theNineFifteen]

    static func stories(in genre: Genre) -> [GuidedStory] {
        all.filter { $0.genre == genre }
    }

    static func story(id: String) -> GuidedStory? {
        all.first { $0.id == id }
    }
}

extension StoryLibrary {
    /// The most conventional shape of the three: one episode, escalating attempts, fully
    /// causally chained. Closest to the material story-grammar research was built on.
    static let thirdCast = GuidedStory(
        id: "third-cast",
        title: "The Third Cast",
        genre: .folkTale,
        prose: """
            Aren had fished the grey water off Coldhaven for thirty years, and for thirty \
            years the sea had given him just enough. He kept a narrow house on the cliff \
            path with his daughter Mira, who mended his nets faster than he could tear them.

            Then, for eleven days, the nets came up empty. Not thin — empty. Aren rowed \
            further out each morning and came back each evening with nothing but weed, and \
            on the eleventh night Mira served him boiled nettles and said nothing about it, \
            which was worse than if she had.

            On the twelfth morning something silver turned in his net. It was a fish the \
            length of his forearm, and when he reached for it, it spoke. It said it could \
            fill his net once, and only once, and asked what he wanted.

            Aren asked for the net to be full. It filled, so heavy he had to bail water to \
            keep the boat down, and he rowed home and sold the catch at the harbour and \
            Mira ate meat for the first time in a year.

            He went back the next morning. The fish was there. He asked for a bigger boat, \
            and got one. He went back again, and asked for the biggest boat in Coldhaven, \
            and got that too.

            On the fourth morning he asked the fish for the sea itself — for every fish in \
            it, forever, so that he would never have to ask again.

            The fish looked at him for a long moment. Then the water went flat and grey and \
            utterly still, the way it does before something very large moves underneath it, \
            and when Aren got home the boats were gone, and the meat was gone, and the \
            house on the cliff path held nothing but Mira and a pile of torn nets.

            She handed him a needle without a word.

            Aren sat down on the step and began to mend. He fished the grey water for \
            another thirty years, and the sea gave him just enough, and he never once told \
            anybody why he had stopped rowing out past the point.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Aren has fished off Coldhaven for thirty years and lives poor but sufficient with his daughter Mira",
                loadBearing: true,
                entities: ["Aren", "Mira"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "For eleven days the nets come up completely empty and they are reduced to eating nettles",
                loadBearing: true,
                entities: ["Aren", "Mira"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .attempts,
                summary: "A silver fish offers to fill his net once, and Aren asks for a full net",
                loadBearing: true,
                entities: ["Aren", "the silver fish"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .attempts,
                summary: "He returns and asks for a bigger boat, then the biggest boat in Coldhaven",
                loadBearing: true,
                entities: ["Aren", "the silver fish"],
                causedBy: 3
            ),
            CanonicalBeat(
                id: 5,
                component: .attempts,
                summary: "On the fourth morning he asks for the entire sea, forever",
                loadBearing: true,
                entities: ["Aren", "the silver fish"],
                causedBy: 4
            ),
            CanonicalBeat(
                id: 6,
                component: .consequences,
                summary: "The water goes still and everything he gained is taken back — the boats, the food, all of it",
                loadBearing: true,
                entities: ["Aren", "the silver fish"],
                causedBy: 5,
                isClimax: true
            ),
            CanonicalBeat(
                id: 7,
                component: .resolution,
                summary: "Mira hands him a needle and he goes back to mending nets for another thirty years, never explaining why",
                loadBearing: true,
                entities: ["Aren", "Mira"],
                causedBy: 6
            ),
        ],
        cast: [
            StoryEntity(
                name: "Aren",
                aliases: ["the fisherman", "the father", "the old man"],
                importance: .central
            ),
            StoryEntity(
                name: "the silver fish",
                aliases: ["the fish", "a talking fish", "the silver one"],
                importance: .central
            ),
            StoryEntity(
                name: "Mira",
                aliases: ["the daughter", "his daughter"],
                importance: .supporting
            ),
            StoryEntity(
                name: "Coldhaven",
                aliases: ["the harbour", "the village", "the town"],
                importance: .incidental
            ),
        ],
        stakes: "Aren already had enough, and asking for everything is what costs him it"
    )
}

extension StoryLibrary {
    /// Character-driven: the events are small and the turn is a decision, so a retelling
    /// that only lists what happened misses the story.
    static let whatTheHouseKept = GuidedStory(
        id: "what-the-house-kept",
        title: "What the House Kept",
        genre: .domestic,
        prose: """
            Nadia had not been inside her mother's house since the spring, and she had \
            certainly not planned to be inside it alone. But the estate agent wanted it \
            emptied by the end of the month, and there was nobody else left to do it.

            Elspeth had been a tidy woman in the way that people are tidy when they are \
            keeping something. Every drawer gave up exactly what it should. The kitchen \
            took two hours. The bedroom took twenty minutes. Nadia was almost finished \
            when she pulled the bottom drawer of the writing desk and found it heavier \
            than the others.

            Letters. Perhaps sixty of them, banded in fours, every envelope addressed in \
            her mother's hand to a Rosalind Vaughan in Cork, and every one of them \
            unopened — because every one of them had been returned.

            Nadia sat on the floor of her mother's bedroom and read the first four, which \
            was as many as she could manage. Rosalind was her mother's sister. Rosalind had \
            been her mother's sister for sixty-one years, through every Christmas and every \
            hospital appointment and every long Sunday afternoon of Nadia's childhood, and \
            not once in all that time had anybody said her name out loud.

            The last letter was dated eight days before the funeral.

            Nadia understood, sitting there, that she had two options and that both of them \
            were permanent. She could put the letters in one of the bags going to the tip, \
            finish the house, hand over the keys, and keep the family exactly the size it \
            had always been. Or she could look up a number in Cork and make a stranger into \
            an aunt, and find out what her mother had spent sixty-one years apologising for.

            She sat with it until the light went. Then she found the number, and she wrote \
            it on the back of her hand rather than her phone, which she recognised even at \
            the time as a way of making it easier to wash off.

            She was still looking at it when the estate agent knocked to collect the keys.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Nadia is alone clearing her late mother Elspeth's house before the estate agent's deadline",
                loadBearing: true,
                entities: ["Nadia", "Elspeth", "the estate agent"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "In the writing desk she finds around sixty letters her mother wrote and had returned unopened",
                loadBearing: true,
                entities: ["Nadia", "Elspeth"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .conflict,
                summary: "They were addressed to Rosalind, her mother's sister, whose name was never once spoken in Nadia's whole childhood",
                loadBearing: true,
                entities: ["Nadia", "Rosalind", "Elspeth"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .goal,
                summary: "Nadia realises she must either throw them away and keep the family as it was, or call Cork and make a stranger into an aunt",
                loadBearing: true,
                entities: ["Nadia", "Rosalind"],
                causedBy: 3,
                isClimax: true
            ),
            CanonicalBeat(
                id: 5,
                component: .consequences,
                summary: "She finds the number but writes it on her hand rather than her phone, knowing that makes it easy to wash off",
                loadBearing: true,
                entities: ["Nadia"],
                causedBy: 4
            ),
        ],
        cast: [
            StoryEntity(
                name: "Nadia",
                aliases: ["the daughter", "the narrator", "she"],
                importance: .central
            ),
            StoryEntity(
                name: "Elspeth",
                aliases: ["her mother", "the mother", "the dead woman"],
                importance: .central
            ),
            StoryEntity(
                name: "Rosalind",
                aliases: ["Rosalind Vaughan", "the sister", "the aunt", "her mother's sister"],
                importance: .central
            ),
            StoryEntity(
                name: "the estate agent",
                aliases: ["the agent"],
                importance: .incidental
            ),
        ],
        stakes: "Nadia can end a silence her mother kept for sixty-one years, or let it close over permanently"
    )

    /// The turn is that the suspicion was unfounded. A retelling that reports the
    /// surveillance and omits the mundane explanation has missed the point entirely.
    static let theNineFifteen = GuidedStory(
        id: "the-nine-fifteen",
        title: "The Nine-Fifteen",
        genre: .mystery,
        prose: """
            Priya took the nine-fifteen from Ealing four days a week, and for most of a \
            year she had shared it with a man in a grey overcoat who got off at her stop \
            and walked the other way.

            She noticed the briefcases in October. He carried one every morning, and it was \
            never the same one twice. Oxblood leather on the Monday. Something cheap and \
            navy on the Tuesday. A hard aluminium case on the Wednesday that he held away \
            from his leg as though it were heavier than it looked.

            After that she could not stop counting them. Nineteen different cases by \
            Christmas. She started sitting where she could see him properly, and then, on \
            a Thursday in January, she did not walk her usual way at all. She followed him.

            He went four streets east, down a service lane behind a parade of shops, and in \
            through a door beside a shuttered dry cleaner's. Priya stood in the lane for \
            some minutes with her heart going and her phone already in her hand, deciding \
            which of the several things she had imagined she was going to tell the police.

            Then the door opened again and a woman came out holding the aluminium case and \
            crying, and said something to him that Priya could not hear, and he shook his \
            head as though it were nothing at all.

            The sign beside the door said Transport for London — Lost Property, Sorting.

            He was a volunteer. Twice a week for six years he had been walking the cases \
            somebody had left on the Piccadilly line back to the people who had lost them, \
            and once or twice a month one of those people cried in a service lane behind a \
            dry cleaner's, and he shook his head as though it were nothing at all.

            Priya went back to the station and got the next train and was ninety minutes \
            late for work. She never told him she had followed him, and she never mentioned \
            the briefcases, and for the remaining four months that they shared the \
            nine-fifteen she found she could not look at him at all.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Priya has shared the nine-fifteen from Ealing with a man in a grey overcoat for most of a year",
                loadBearing: true,
                entities: ["Priya", "the man in the grey overcoat"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "She notices he carries a different briefcase every single morning, and counts nineteen by Christmas",
                loadBearing: true,
                entities: ["Priya", "the man in the grey overcoat", "the briefcases"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .conflict,
                summary: "She becomes fixated, imagines something criminal, and one January morning follows him instead of going to work",
                loadBearing: true,
                entities: ["Priya", "the man in the grey overcoat"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .attempts,
                summary: "She waits in a service lane with her phone out, deciding what to tell the police",
                loadBearing: true,
                entities: ["Priya"],
                causedBy: 3
            ),
            CanonicalBeat(
                id: 5,
                component: .resolution,
                summary: "The door is a lost property office — he is a volunteer who has spent six years returning cases to the people who lost them",
                loadBearing: true,
                entities: ["Priya", "the man in the grey overcoat", "the crying woman", "the briefcases"],
                causedBy: 4,
                isClimax: true
            ),
            CanonicalBeat(
                id: 6,
                component: .consequences,
                summary: "Priya says nothing, and for their last four months on the same train she cannot look at him",
                loadBearing: true,
                entities: ["Priya", "the man in the grey overcoat"],
                causedBy: 5
            ),
        ],
        cast: [
            StoryEntity(
                name: "Priya",
                aliases: ["the woman", "the commuter", "the narrator", "she"],
                importance: .central
            ),
            StoryEntity(
                name: "the man in the grey overcoat",
                aliases: ["the man", "the volunteer", "the stranger", "grey overcoat"],
                importance: .central
            ),
            StoryEntity(
                name: "the crying woman",
                aliases: ["the woman who came out", "the owner"],
                importance: .supporting
            ),
            StoryEntity(
                name: "the briefcases",
                aliases: ["the cases", "the suitcases", "the bags"],
                importance: .central
            ),
        ],
        stakes: "Priya's suspicion turns out to say everything about her and nothing about him"
    )
}
