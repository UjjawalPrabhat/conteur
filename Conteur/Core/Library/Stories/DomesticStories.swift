import Foundation

/// Domestic stories: small events, and a turn that is a decision rather than a happening.
///
/// A retelling that only lists what occurred misses these, which is the point of having
/// them — they are the genre that punishes reporting.
enum DomesticStories {
    static let all: [GuidedStory] = [whatTheHouseKept, secondKitchen, longWayRound, nobodysFault, tuesdaysChair]

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
                entities: ["Nadia", "Elspeth", "the letters"],
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
            StoryEntity(name: "Nadia", aliases: ["the daughter", "the narrator"], importance: .central),
            StoryEntity(name: "Elspeth", aliases: ["her mother", "the mother", "the dead woman"], importance: .central),
            StoryEntity(name: "Rosalind", aliases: ["Rosalind Vaughan", "the sister", "the aunt", "her mother's sister"], importance: .central),
            StoryEntity(name: "the letters", aliases: ["the letters", "sixty letters", "the envelopes"], importance: .central),
            StoryEntity(name: "the estate agent", aliases: ["the agent"], importance: .incidental),
        ],
        stakes: "Nadia can end a silence her mother kept for sixty-one years, or let it close over permanently"
    )

    /// The turn is a refusal. Nothing happens except that somebody says no.
    static let secondKitchen = GuidedStory(
        id: "second-kitchen",
        title: "The Second Kitchen",
        genre: .domestic,
        prose: """
            Gerald had the kitchen rebuilt in the autumn, eighteen months after Moira died, \
            and he had it rebuilt exactly.

            Not similarly. Exactly. He had photographs, and he used them. The same units in \
            the same laminate, which he found in the end through a man in Wolverhampton who \
            dealt in old stock. The same handles. The tiles were the closest match available \
            and it bothered him. The kettle went back on the left even though the socket was \
            now on the right, so the flex crossed the worktop, which is how it had been.

            His daughter Priya came up from Bristol for the weekend to see it. He had been \
            looking forward to that for a month.

            She stood in the doorway with her bag still on her shoulder for a long time. \
            Then she said, "Dad, what have you done."

            Gerald explained about the man in Wolverhampton. He was quite a long way into it \
            before he understood that she was not asking how.

            What Priya said, eventually, sitting down at the table that was in the same place \
            as the old table, was that she had spent eighteen months learning to walk into \
            this house without expecting her mother to be in it, and that he had just put it \
            all back, and that she could not do it twice.

            Gerald said he had done it so that it would still be her mother's house.

            Priya said that was the problem.

            They had dinner. It was fine. She left on the Sunday two hours earlier than she \
            had said she would, and rang from the motorway to say she was sorry about the \
            two hours, and neither of them mentioned the kitchen.

            She came at Christmas, and at Easter, and every few months after that, and she \
            has never once eaten a meal in that kitchen since. She eats in the dining room. \
            Gerald sets the dining room table now without being asked, and has never told \
            her that he understands why.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Eighteen months after his wife Moira died, Gerald has the kitchen rebuilt to match hers exactly, from photographs",
                loadBearing: true,
                entities: ["Gerald", "Moira", "the kitchen"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "His daughter Priya comes up from Bristol to see it, and stands in the doorway asking what he has done",
                loadBearing: true,
                entities: ["Gerald", "Priya", "the kitchen"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .conflict,
                summary: "Priya says she spent eighteen months learning to enter the house without expecting her mother, and he has put it all back",
                loadBearing: true,
                entities: ["Priya", "Gerald", "Moira"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .goal,
                summary: "Gerald says he did it so it would still be her mother's house, and Priya says that is exactly the problem",
                loadBearing: true,
                entities: ["Gerald", "Priya"],
                causedBy: 3,
                isClimax: true
            ),
            CanonicalBeat(
                id: 5,
                component: .consequences,
                summary: "She leaves early, and has never eaten in that kitchen since — Gerald now lays the dining room table without being asked and never says why",
                loadBearing: true,
                entities: ["Gerald", "Priya", "the kitchen"],
                causedBy: 4
            ),
        ],
        cast: [
            StoryEntity(name: "Gerald", aliases: ["the father", "the dad", "the widower"], importance: .central),
            StoryEntity(name: "Priya", aliases: ["the daughter"], importance: .central),
            StoryEntity(name: "the kitchen", aliases: ["a kitchen", "the new kitchen"], importance: .central),
            StoryEntity(name: "Moira", aliases: ["the mother", "the wife", "her mother"], importance: .central),
        ],
        stakes: "Gerald rebuilt the kitchen to keep his wife in the house, and it is the reason his daughter will not sit in it"
    )

    /// The detour is the whole story, and it is never explained by either of them.
    static let longWayRound = GuidedStory(
        id: "long-way-round",
        title: "The Long Way Round",
        genre: .domestic,
        prose: """
            The appointment was at eleven and it was a fifty minute drive, and Ademola \
            picked his father up at twenty past nine, which his father commented on twice \
            before they got out of the estate.

            They had done four of these. This was the one where they would be told what the \
            scan had found, and both of them knew that, and neither of them said it, and \
            what they discussed instead was the roadworks on the ring road, at some length, \
            with real conviction on both sides.

            At the roundabout that took you onto the dual carriageway, Ademola went the \
            other way.

            His father noticed immediately. He was seventy-eight and had been driving that \
            junction since before the roundabout existed. He said, "That's the wrong way."

            Ademola said the ring road would be solid.

            His father looked at him for a second, and then said, "Right," and turned the \
            radio on.

            The other way took them along the coast. It added twenty-five minutes to a \
            journey they had ninety minutes for. Neither of them said anything about it for \
            the first ten of those, and then his father started talking about a caravan they \
            had taken to Filey in 1987, which had a leak, and which Ademola had genuinely \
            not thought about once in thirty-six years.

            He talked for the whole coast road. Ademola drove slowly. There was a stretch \
            after Speeton where you can see all the way out, and his father stopped talking \
            for about a mile of it, and then started again.

            They got to the hospital at eight minutes to eleven. They were called in at \
            twenty past. The scan had found what they had both assumed it had found.

            On the way home Ademola took the dual carriageway, and it was clear, and it took \
            forty-five minutes, and his father did not mention the roadworks or the caravan \
            or the coast, and he never has since, and neither has Ademola.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Ademola is driving his seventy-eight-year-old father to the hospital appointment where they will be told what the scan found",
                loadBearing: true,
                entities: ["Ademola", "his father"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "Neither will mention it, so they argue about roadworks instead, and at the roundabout Ademola deliberately goes the wrong way",
                loadBearing: true,
                entities: ["Ademola", "his father"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .conflict,
                summary: "His father says it is the wrong way, Ademola claims the ring road will be solid, and his father says only \"Right\" and turns on the radio",
                loadBearing: true,
                entities: ["Ademola", "his father"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .goal,
                summary: "The coast road adds twenty-five minutes, and his father spends all of it talking about a leaking caravan they took to Filey in 1987",
                loadBearing: true,
                entities: ["Ademola", "his father", "the caravan"],
                causedBy: 3,
                isClimax: true
            ),
            CanonicalBeat(
                id: 5,
                component: .consequences,
                summary: "The scan had found what they both assumed, and on the way home Ademola takes the fast road and neither of them ever mentions the detour again",
                loadBearing: true,
                entities: ["Ademola", "his father"],
                causedBy: 4
            ),
        ],
        cast: [
            StoryEntity(name: "Ademola", aliases: ["the son", "the driver", "the narrator"], importance: .central),
            StoryEntity(name: "his father", aliases: ["the father", "the old man", "his dad"], importance: .central),
            StoryEntity(name: "the caravan", aliases: ["a caravan", "the holiday", "Filey"], importance: .supporting),
        ],
        stakes: "Ademola cannot say anything to his father, so he buys him twenty-five extra minutes instead"
    )

    /// The argument is never about the shelf. A retelling that reports the shelf has told
    /// the wrong story accurately.
    static let nobodysFault = GuidedStory(
        id: "nobodys-fault",
        title: "Nobody's Fault",
        genre: .domestic,
        prose: """
            The shelf came off the wall in the hall at about half past seven on a Thursday, \
            with everything on it, including a bowl that had been Yusuf's grandmother's and \
            was now in roughly nine pieces on the floorboards.

            Yusuf had put the shelf up in March. Dana had said at the time that the plugs \
            looked small for plasterboard, and Yusuf had said they were the ones that came \
            with it.

            So there was a version of this available to both of them, and they both went and \
            got it.

            It lasted forty minutes and covered the shelf, the plugs, the bowl, whether Dana \
            had actually said anything in March or was constructing that afterwards, the \
            spare room, Yusuf's brother, the fact that Dana had told her mother about the \
            spare room before telling Yusuf she had decided anything, and then, briefly and \
            with great precision, the spare room again.

            Then Dana said, "I'm not doing it," and sat down on the stairs.

            Yusuf stood in the hall holding two pieces of his grandmother's bowl and \
            understood that they had not been arguing about a shelf since roughly minute \
            four, and that the actual sentence had now been said, and that it could not be \
            got back into the box it came out of.

            He said, "Since when."

            Dana said, "March."

            They sat on the stairs for a while. At some point Yusuf put the two pieces down \
            on the floor next to the other seven, quite carefully, in the shape the bowl had \
            been.

            He mended it that weekend, badly, with the wrong glue, and it went back up on a \
            new shelf with the correct plugs, and it is still there. You can see the lines \
            if you know to look for them, and everybody who comes to the house is told the \
            story of the shelf, which is a very funny story, and which Yusuf tells extremely \
            well.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "A shelf Yusuf put up in March comes off the hall wall, breaking his grandmother's bowl, and Dana had warned about the plugs at the time",
                loadBearing: true,
                entities: ["Yusuf", "Dana", "the bowl"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "They argue for forty minutes, ranging well past the shelf to his brother, her mother, and the spare room",
                loadBearing: true,
                entities: ["Yusuf", "Dana"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .conflict,
                summary: "Dana says \"I'm not doing it\" and sits down on the stairs",
                loadBearing: true,
                entities: ["Dana", "Yusuf"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .goal,
                summary: "Yusuf realises they stopped arguing about the shelf around minute four, asks since when, and she says March",
                loadBearing: true,
                entities: ["Yusuf", "Dana"],
                causedBy: 3,
                isClimax: true
            ),
            CanonicalBeat(
                id: 5,
                component: .consequences,
                summary: "He mends the bowl badly and it goes back up on a new shelf, and the funny story of the shelf is what every visitor gets told",
                loadBearing: true,
                entities: ["Yusuf", "the bowl"],
                causedBy: 4
            ),
        ],
        cast: [
            StoryEntity(name: "Yusuf", aliases: ["the husband", "the narrator"], importance: .central),
            StoryEntity(name: "Dana", aliases: ["the wife", "his partner"], importance: .central),
            StoryEntity(name: "the bowl", aliases: ["a bowl", "the grandmother's bowl"], importance: .central),
            StoryEntity(name: "the shelf", aliases: ["a shelf", "the new shelf"], importance: .supporting),
        ],
        stakes: "The shelf is the story they tell instead of the one where Dana said she was leaving"
    )

    /// She has nothing left to be there for, and goes anyway. The reason is the turn.
    static let tuesdaysChair = GuidedStory(
        id: "tuesdays-chair",
        title: "Tuesday's Chair",
        genre: .domestic,
        prose: """
            The group met on Tuesdays in the back room of a library in Handsworth, eight \
            chairs in a rough circle, and Margaret had been in one of them for two years and \
            four months.

            She had come at first because she could not be in her house between six and nine \
            in the evening. That was the specific problem. Not the whole of it, but the part \
            with edges on it, and the group was between six and nine.

            Somewhere in the second year it stopped. She noticed it on a Tuesday in \
            February, driving over: she was going to a thing she enjoyed, with people she \
            liked, and she was not going because she could not be at home. She could be at \
            home perfectly well. She had been at home all afternoon.

            She thought she probably ought to tell them, and stop, because there were eight \
            chairs and a waiting list.

            What she did instead was arrive early the next week and sit in the chair by the \
            radiator, which was the one people took when it was their first time, and when a \
            man of about sixty came in and stood in the doorway doing the thing they all did \
            in the doorway, she got up and gave him it and took a hard chair by the window.

            She did that every week for another eleven months. She never took the radiator \
            chair again and she never mentioned it to anybody, and when a new person came she \
            was already sitting somewhere else.

            Rita, who ran it, asked her once — the June after — whether she was still getting \
            what she needed out of it.

            Margaret said she was, which was true, and did not say what, which was also true.

            She stopped in the January, when the group had run for six weeks without a single \
            new person walking through the door.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Margaret has attended a Tuesday support group in a Handsworth library for over two years, originally because she could not be in her house in the evenings",
                loadBearing: true,
                entities: ["Margaret", "the group"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "One Tuesday in February she realises she no longer needs it — she could be at home perfectly well",
                loadBearing: true,
                entities: ["Margaret"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .conflict,
                summary: "She knows she ought to stop, because there are only eight chairs and a waiting list",
                loadBearing: true,
                entities: ["Margaret", "the group"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .goal,
                summary: "Instead she arrives early to sit in the chair newcomers take, and gives it up to a man in the doorway, moving to a hard chair by the window",
                loadBearing: true,
                entities: ["Margaret", "the man in the doorway"],
                causedBy: 3,
                isClimax: true
            ),
            CanonicalBeat(
                id: 5,
                component: .consequences,
                summary: "She does that for eleven more months without telling anybody, tells Rita only that she is still getting what she needs, and stops when six weeks pass with no new arrivals",
                loadBearing: true,
                entities: ["Margaret", "Rita"],
                causedBy: 4
            ),
        ],
        cast: [
            StoryEntity(name: "Margaret", aliases: ["the woman", "the narrator"], importance: .central),
            StoryEntity(name: "the group", aliases: ["the support group", "the meeting", "the circle"], importance: .central),
            StoryEntity(name: "the man in the doorway", aliases: ["the new man", "the newcomer"], importance: .supporting),
            StoryEntity(name: "Rita", aliases: ["the facilitator", "the woman who ran it"], importance: .supporting),
        ],
        stakes: "Margaret keeps coming for two years after she stops needing it, so that the chair by the radiator is always free"
    )
}
