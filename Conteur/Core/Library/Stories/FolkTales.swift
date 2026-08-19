import Foundation

/// Folk tales: one episode, escalating attempts, a consequence that lands on the teller.
///
/// A listener expects setting, an initiating event, attempts, consequences and a
/// resolution — so each of these contains all five, and a retelling is measured against
/// what the story actually has rather than what the genre promises.
enum FolkTales {
    static let all: [GuidedStory] = [thirdCast, saltRoad, coatOfNineWinters, whatTheMillerOwed, lanternKeeper]

    /// The most conventional shape of the set: escalating wishes, fully causally chained.
    /// Closest to the material story-grammar research was built on.
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
            StoryEntity(name: "Aren", aliases: ["the fisherman", "the father", "the old man"], importance: .central),
            StoryEntity(name: "the silver fish", aliases: ["the fish", "a talking fish", "the silver one"], importance: .central),
            StoryEntity(name: "Mira", aliases: ["the daughter", "his daughter"], importance: .supporting),
            StoryEntity(name: "Coldhaven", aliases: ["the harbour", "the village", "the town"], importance: .incidental),
        ],
        stakes: "Aren already had enough, and asking for everything is what costs him it"
    )

    /// The danger was never there. A retelling that stops at the bargain has missed it.
    static let saltRoad = GuidedStory(
        id: "salt-road",
        title: "The Salt Road",
        genre: .folkTale,
        prose: """
            The salt road ran forty miles from Ostgate down to the coast, and everybody in \
            Ostgate agreed on one thing about it, which was that nobody walked it alone. \
            Wren had heard the reason a hundred times without ever hearing it twice the \
            same way.

            Her family sold salt. That was the whole of it — her father carried it down and \
            carried coin back, twice a year, and in between they ate what the coin allowed. \
            Then he came off a ladder in the spring and the leg set crooked, and there was \
            eleven stone of salt in the barn and nobody to walk it anywhere.

            So Wren went to Marrow, who kept a hedge above the north field and was said to \
            arrange things. Marrow listened, and named a price, and the price was Wren's \
            voice. Not her tongue. Just the sound of it. Safe passage down and safe passage \
            back, and Marrow would keep the voice in a stoppered jar on a shelf.

            Wren thought about the hundred versions of the reason nobody walked the road \
            alone. Then she agreed.

            She walked the forty miles. Nothing happened. Not a thing — not a shadow, not a \
            sound, not so much as a dog. She slept one night in a dry ditch and woke up with \
            frost on her and walked on.

            At the coast the salt merchant offered her a third of what it was worth, and \
            Wren opened her mouth to argue and remembered, and closed it, and took the \
            third.

            She was most of the way home before she met a carter who told her, cheerfully \
            and at length, that there had never been anything on the salt road. That the \
            story was forty years old and had been made up by a woman in Ostgate whose \
            children kept wandering off, and that it had worked so well on them it had gone \
            on working on everybody since.

            Wren walked the last nine miles turning that over. Then she went past Marrow's \
            hedge without stopping, and she has not spoken since, and she has never once \
            told anybody why.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Wren's family sells salt in Ostgate, and everyone says the forty-mile road to the coast cannot be walked alone",
                loadBearing: true,
                entities: ["Wren", "Ostgate"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "Her father breaks his leg, so the salt has to be walked down by Wren or not at all",
                loadBearing: true,
                entities: ["Wren", "her father"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .attempts,
                summary: "She trades her voice to Marrow the hedge-witch for safe passage there and back",
                loadBearing: true,
                entities: ["Wren", "Marrow"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .attempts,
                summary: "She walks the whole forty miles and absolutely nothing happens",
                loadBearing: true,
                entities: ["Wren"],
                causedBy: 3
            ),
            CanonicalBeat(
                id: 5,
                component: .consequences,
                summary: "Voiceless at the coast she cannot argue with the merchant and sells the salt for a third of its worth",
                loadBearing: true,
                entities: ["Wren", "the salt merchant"],
                causedBy: 4
            ),
            CanonicalBeat(
                id: 6,
                component: .consequences,
                summary: "A carter tells her there was never anything on the road — the story was invented forty years ago to keep children from wandering",
                loadBearing: true,
                entities: ["Wren", "the carter"],
                causedBy: 5,
                isClimax: true
            ),
            CanonicalBeat(
                id: 7,
                component: .resolution,
                summary: "Wren walks past Marrow's hedge without stopping and has not spoken since, never explaining why",
                loadBearing: true,
                entities: ["Wren", "Marrow"],
                causedBy: 6
            ),
        ],
        cast: [
            StoryEntity(name: "Wren", aliases: ["the girl", "the daughter"], importance: .central),
            StoryEntity(name: "Marrow", aliases: ["the hedge-witch", "the witch"], importance: .central),
            StoryEntity(name: "the carter", aliases: ["a carter", "the man on the road"], importance: .central),
            StoryEntity(name: "her father", aliases: ["the father"], importance: .supporting),
            StoryEntity(name: "the salt merchant", aliases: ["the merchant", "the buyer"], importance: .supporting),
            StoryEntity(name: "Ostgate", aliases: ["the town", "the village"], importance: .incidental),
        ],
        stakes: "Wren gives away the one thing she needed to guard against a danger that was never there"
    )

    /// The grief was postponed, not spared. The turn is that it waited undiminished.
    static let coatOfNineWinters = GuidedStory(
        id: "coat-of-nine-winters",
        title: "The Coat of Nine Winters",
        genre: .folkTale,
        prose: """
            Halder was the best tailor in Vardenholt, which was a town where being the best \
            tailor mattered, because Vardenholt had nine months of winter and three months \
            of a season nobody bothered naming.

            His wife Ilse died in the second week of a January so cold the bells cracked. \
            Their son Emrys was eleven. He did not stop crying, and he did not stop \
            shaking, and after a fortnight Halder could no longer tell which was the cold \
            and which was the other thing, and neither could Emrys.

            So Halder did what he knew how to do. He sat down at the bench and he made a \
            coat. He lined it with nine winters — his own, the nine hardest he could \
            remember — and he stitched them in so close that nothing could get through the \
            wool in either direction. Then he put it on the boy.

            It worked. Emrys stopped shaking that night. He also stopped crying, and he did \
            not start again.

            He wore the coat for nine years. He wore it through two more winters that \
            cracked the bells and through his own apprenticeship and through the funeral of \
            his grandmother, at which he stood very straight and felt, by his own later \
            account, approximately nothing. People in Vardenholt said what a steady young \
            man he had turned out, considering.

            The spring he turned twenty he was up on the roof of the mill in the three \
            unnamed months, and the sun came round, and he took the coat off to work.

            It was all still there. Every bit of it, exactly as it had been in the second \
            week of that January, not one day older and not one degree less. He sat down on \
            the mill roof and cried for two hours, at twenty, for a woman who had been dead \
            for nine years.

            He brought the coat back that evening. Halder looked at it a long time, and then \
            put it in the stove, and the two of them were cold all that winter, which was \
            the first winter either of them had properly felt in nine years.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Halder is the best tailor in Vardenholt, a town with nine months of winter",
                loadBearing: true,
                entities: ["Halder", "Vardenholt"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "His wife Ilse dies and their eleven-year-old son Emrys will not stop crying or shaking",
                loadBearing: true,
                entities: ["Halder", "Ilse", "Emrys"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .attempts,
                summary: "Halder sews a coat lined with nine winters so nothing can get through the wool in either direction",
                loadBearing: true,
                entities: ["Halder", "Emrys", "the coat"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .attempts,
                summary: "Emrys wears it for nine years and feels nothing — not the cold, and not his mother either",
                loadBearing: true,
                entities: ["Emrys", "the coat"],
                causedBy: 3
            ),
            CanonicalBeat(
                id: 5,
                component: .consequences,
                summary: "At twenty he takes the coat off on a mill roof and the grief is waiting exactly as it was, not one day older",
                loadBearing: true,
                entities: ["Emrys", "the coat"],
                causedBy: 4,
                isClimax: true
            ),
            CanonicalBeat(
                id: 6,
                component: .resolution,
                summary: "He returns the coat, Halder burns it, and both of them are properly cold for the first time in nine years",
                loadBearing: true,
                entities: ["Halder", "Emrys", "the coat"],
                causedBy: 5
            ),
        ],
        cast: [
            StoryEntity(name: "Halder", aliases: ["the tailor", "the father"], importance: .central),
            StoryEntity(name: "Emrys", aliases: ["the son", "the boy"], importance: .central),
            StoryEntity(name: "the coat", aliases: ["a coat", "the winter coat"], importance: .central),
            StoryEntity(name: "Ilse", aliases: ["the wife", "the mother"], importance: .supporting),
            StoryEntity(name: "Vardenholt", aliases: ["the town"], importance: .incidental),
        ],
        stakes: "The coat did not spare Emrys his grief, it only held nine years of it waiting for him"
    )

    /// He pays with something that was never his. The cost falls on somebody else first.
    static let whatTheMillerOwed = GuidedStory(
        id: "what-the-miller-owed",
        title: "What the Miller Owed",
        genre: .folkTale,
        prose: """
            Tam ran the only mill in Hollowby, which sounds like security and is in fact the \
            opposite, because the only mill in a village is the only mill anybody can blame.

            He had borrowed against three bad harvests from a grain factor named Beske, who \
            was patient in the way that people are patient when patience costs them nothing. \
            At the fourth harvest Beske stopped being patient and called the whole debt.

            Tam offered him the mill. Beske said he had no use for a mill in Hollowby. Tam \
            offered the horse, and Beske said he had four. Tam offered his own labour for as \
            many years as it took, and Beske looked at Tam's hands and said, without any \
            unkindness at all, that he did not think there were that many years in them.

            Then Beske mentioned, as though it had only just occurred to him, that he was \
            short of hands at the drying sheds, and that Tam's apprentice was young and \
            strong and had four years still to run on her indenture.

            Sela had come to the mill at twelve. She was seventeen. The indenture was a \
            piece of paper in a tin, and Tam's name was on it, and Sela's name was on it, \
            and only one of them was in the room.

            He signed it over.

            They came for her on a Tuesday. She did not shout at him, which he had been \
            braced for. She looked at him the way you look at a thing you are working out, \
            and then she got into the cart.

            The mill ran. That was the strange part. The stones turned and the wheel turned \
            and the debt came down and was gone inside two years. What did not happen was \
            anybody in Hollowby bringing grain to it. They walked it eleven miles to \
            Aldmarsh instead, in all weather, for eleven years, and never once said why, \
            because they did not need to.

            Tam ground his own flour, alone, until he died. He had paid every penny he owed.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Tam runs the only mill in Hollowby and is deep in debt to the grain factor Beske",
                loadBearing: true,
                entities: ["Tam", "Beske", "Hollowby"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "At the fourth harvest Beske calls in the whole debt at once",
                loadBearing: true,
                entities: ["Tam", "Beske"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .attempts,
                summary: "Tam offers the mill, then the horse, then his own labour, and Beske refuses all three",
                loadBearing: true,
                entities: ["Tam", "Beske"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .attempts,
                summary: "Beske asks instead for the four remaining years of the indenture of Sela, Tam's apprentice, and Tam signs it over",
                loadBearing: true,
                entities: ["Tam", "Beske", "Sela"],
                causedBy: 3,
                isClimax: true
            ),
            CanonicalBeat(
                id: 5,
                component: .consequences,
                summary: "Sela is taken away without a word of reproach, and the debt is cleared inside two years",
                loadBearing: true,
                entities: ["Tam", "Sela"],
                causedBy: 4
            ),
            CanonicalBeat(
                id: 6,
                component: .consequences,
                summary: "Nobody in Hollowby brings grain to the mill again, walking eleven miles to Aldmarsh instead for eleven years",
                loadBearing: true,
                entities: ["Tam", "Hollowby"],
                causedBy: 5
            ),
            CanonicalBeat(
                id: 7,
                component: .resolution,
                summary: "Tam grinds his own flour alone until he dies, having paid every penny he owed",
                loadBearing: true,
                entities: ["Tam"],
                causedBy: 6
            ),
        ],
        cast: [
            StoryEntity(name: "Tam", aliases: ["the miller"], importance: .central),
            StoryEntity(name: "Sela", aliases: ["the apprentice", "the girl"], importance: .central),
            StoryEntity(name: "Beske", aliases: ["the grain factor", "the factor", "the lender"], importance: .central),
            StoryEntity(name: "Hollowby", aliases: ["the village", "the town"], importance: .incidental),
        ],
        stakes: "Tam settles his own debt with four years of somebody else's life"
    )

    /// The blank night is the story. A retelling that never explains it has told a mystery
    /// and left out the answer.
    static let lanternKeeper = GuidedStory(
        id: "lantern-keeper",
        title: "The Lantern Keeper's Daughter",
        genre: .folkTale,
        prose: """
            The light at Cape Meren had been lit every night for a hundred and six years, \
            first by Isolde's grandfather and then by her father Bren, and after that by \
            Isolde, who took it over at nineteen and did not put it down again.

            When Bren died she found his log. Every keeper kept one: the date, the weather, \
            the hour the light went up, in a column down the page, for forty-one years. She \
            read the whole thing over four nights, which is the sort of thing you do in the \
            week after.

            There was one blank line. The fourteenth of November, and nothing beside it. Not \
            a note, not a scratch, not the weather.

            She went to the wreck registry at Ostmouth, because if the light had not gone up \
            then somebody would have written down what happened, and somebody had. A coastal \
            packet, the fourteenth of November, gone onto the Meren teeth in fog with all \
            hands.

            Then she asked. There were four men left in the village old enough, and she \
            asked all four, and every one of them found something to look at. The fourth \
            one, who was ninety and had nothing much left to lose, said only: your father \
            went down to the water that night. Not up to the light. Down to the water.

            It took Isolde most of a year to find the passenger list, and when she did, her \
            mother's name was on it.

            He had known which ship it was. He had gone down to the shingle to be there when \
            it came in, and while he stood on the shingle the light stayed dark, and the \
            ship came onto the teeth with his wife aboard and forty other people who were \
            not his wife.

            Isolde lit the lantern that night, and every night for another forty-three \
            years, in every kind of weather, without ever missing one. She kept the log the \
            way her father had taught her.

            She never wrote down what she had found, and she never told a single soul.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Isolde keeps the light at Cape Meren, as her father Bren and grandfather did before her",
                loadBearing: true,
                entities: ["Isolde", "Bren", "Cape Meren"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "After her father dies she reads his forty-one-year log and finds a single blank night",
                loadBearing: true,
                entities: ["Isolde", "Bren", "the log"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .attempts,
                summary: "She checks the wreck registry and finds a coastal packet lost on the Meren teeth in fog that same night",
                loadBearing: true,
                entities: ["Isolde"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .attempts,
                summary: "She asks the four old men in the village, and only the oldest will say anything — her father went down to the water, not up to the light",
                loadBearing: true,
                entities: ["Isolde", "the oldest man"],
                causedBy: 3
            ),
            CanonicalBeat(
                id: 5,
                component: .consequences,
                summary: "Her mother's name is on the passenger list — he had gone to meet one ship and let it wreck with forty others aboard",
                loadBearing: true,
                entities: ["Isolde", "Bren", "her mother"],
                causedBy: 4,
                isClimax: true
            ),
            CanonicalBeat(
                id: 6,
                component: .resolution,
                summary: "Isolde lights the lantern every night for another forty-three years and never tells anybody what she found",
                loadBearing: true,
                entities: ["Isolde", "the log"],
                causedBy: 5
            ),
        ],
        cast: [
            StoryEntity(name: "Isolde", aliases: ["the keeper", "the daughter"], importance: .central),
            StoryEntity(name: "Bren", aliases: ["her father", "the father", "the old keeper"], importance: .central),
            StoryEntity(name: "her mother", aliases: ["the mother", "his wife"], importance: .central),
            StoryEntity(name: "the log", aliases: ["the logbook", "the record", "the journal"], importance: .supporting),
            StoryEntity(name: "the oldest man", aliases: ["the old man", "the ninety-year-old"], importance: .supporting),
            StoryEntity(name: "Cape Meren", aliases: ["the lighthouse", "the cape", "the light"], importance: .incidental),
        ],
        stakes: "Bren chose one ship over every ship, and Isolde spends a lifetime deciding not to"
    )
}
