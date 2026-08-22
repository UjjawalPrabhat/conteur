import Foundation

/// Mysteries: a suspicion, an investigation, and an explanation that is smaller than the
/// suspicion was.
///
/// Every one of these turns on the reveal, so a retelling can cover the surveillance
/// faithfully and still have missed the story. That makes them the sharpest test of whether
/// coverage and stakes are being measured separately.
enum Mysteries {
    static let all: [GuidedStory] = [nineFifteen, wrongUmbrella, roomFourB, meterReading, cyclistOnFerndale]

    static let nineFifteen = GuidedStory(
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
            StoryEntity(name: "Priya", aliases: ["the woman", "the commuter", "the narrator"], importance: .central),
            StoryEntity(name: "the man in the grey overcoat", aliases: ["the man", "the volunteer", "the stranger", "grey overcoat"], importance: .central),
            StoryEntity(name: "the briefcases", aliases: ["the cases", "the suitcases", "the bags"], importance: .central),
            StoryEntity(name: "the crying woman", aliases: ["the woman who came out", "the owner"], importance: .supporting),
        ],
        stakes: "Priya's suspicion turns out to say everything about her and nothing about him"
    )

    /// The secret she uncovers is her own. The reveal reframes everything before it.
    static let wrongUmbrella = GuidedStory(
        id: "wrong-umbrella",
        title: "The Wrong Umbrella",
        genre: .mystery,
        prose: """
            Bea picked up the wrong umbrella at the Hollis Street library on a Wednesday in \
            November, which she did not discover until she was four streets away and it \
            would not open properly.

            It was a good one. Wooden handle, dark green, and a luggage tag looped to the \
            shaft with a name and a phone number on it in small careful capitals: J. \
            ARMITAGE.

            She meant to take it back the next day. What she did instead, that evening, was \
            look up the name, because there had been something in the handwriting.

            J. Armitage came back as a piano tuner in Fintry, retired, and then — three pages \
            in — as a J. Armitage who had given evidence at an inquest in 1994 into the death \
            of a fifteen-year-old boy at a swimming pool in Cumbernauld.

            Bea sat with that for two days. She was thirty-eight, and she had grown up in \
            Cumbernauld, and she had been at that pool, and she had never once been told how \
            her brother Callum drowned, only that he had.

            She read the whole inquest. It took her a week to get hold of it and forty \
            minutes to read.

            J. Armitage was the lifeguard. He had been nineteen. He had gone in for Callum \
            and got him out and worked on him for eleven minutes before the ambulance came, \
            and the inquest had found no fault with him at all, and he had given up the job \
            afterwards and become a piano tuner.

            He had also, twice a year for twenty-four years, sent a card to Bea's mother, \
            which Bea had never seen, and which her mother had never mentioned, and which the \
            inquest had nothing to say about because it was not in the inquest — it was on the \
            mantelpiece in her mother's back room, in a bundle, under a photograph.

            Bea returned the umbrella to the library and did not leave a note.

            She has never called the number, and she has never asked her mother about the \
            cards, and she can still recite the phone number from the luggage tag.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Bea takes the wrong umbrella from a library, and it has a luggage tag naming J. Armitage with a phone number",
                loadBearing: true,
                entities: ["Bea", "the umbrella", "J. Armitage"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "Instead of returning it she looks the name up, and finds a J. Armitage who gave evidence at a 1994 inquest into a boy's drowning",
                loadBearing: true,
                entities: ["Bea", "J. Armitage"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .conflict,
                summary: "Bea grew up in that town and was at that pool — the boy was her brother Callum, and she was never told how he drowned",
                loadBearing: true,
                entities: ["Bea", "Callum"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .attempts,
                summary: "She spends a week obtaining the full inquest and forty minutes reading it",
                loadBearing: true,
                entities: ["Bea"],
                causedBy: 3
            ),
            CanonicalBeat(
                id: 5,
                component: .resolution,
                summary: "Armitage was the nineteen-year-old lifeguard who pulled Callum out and worked on him for eleven minutes, was found blameless, and quit — and has sent her mother a card twice a year for twenty-four years",
                loadBearing: true,
                entities: ["Bea", "J. Armitage", "Callum", "her mother"],
                causedBy: 4,
                isClimax: true
            ),
            CanonicalBeat(
                id: 6,
                component: .consequences,
                summary: "Bea returns the umbrella without a note, never calls the number, never asks her mother about the cards, and still knows the number by heart",
                loadBearing: true,
                entities: ["Bea", "the umbrella", "her mother"],
                causedBy: 5
            ),
        ],
        cast: [
            StoryEntity(name: "Bea", aliases: ["the woman", "the narrator"], importance: .central),
            StoryEntity(name: "J. Armitage", aliases: ["Armitage", "the lifeguard", "the piano tuner"], importance: .central),
            StoryEntity(name: "Callum", aliases: ["her brother", "the boy", "the brother"], importance: .central),
            StoryEntity(name: "the umbrella", aliases: ["an umbrella", "the green umbrella"], importance: .central),
            StoryEntity(name: "her mother", aliases: ["the mother", "Bea's mother"], importance: .supporting),
        ],
        stakes: "Bea went looking into a stranger and found the answer nobody in her family would give her"
    )

    /// The guest is not hiding anything criminal. She is hiding that she has nowhere else.
    static let roomFourB = GuidedStory(
        id: "room-four-b",
        title: "Room 4B",
        genre: .mystery,
        prose: """
            Tomas cleaned nine rooms a shift at the Vandemere, which was the kind of hotel \
            where the corridor carpet had been chosen to hide things, and he had cleaned 4B \
            forty-one times.

            The bed was never slept in. Not made-up-again slept in — he could tell the \
            difference, everybody in the job can. Not slept in. Meanwhile the armchair by the \
            window had a dip in it you could have cast in plaster, and there was always one \
            cup, washed, upside down on the towel.

            The guest was a Ms Halloran, who paid weekly in cash and was never there between \
            eight and six.

            He worked through the possibilities in the order anybody would. He decided it was \
            not drugs, because there was nothing, ever, and he had cleaned rooms where there \
            was. He decided it was not an affair, because there was only ever one cup.

            In the fifth week he found, behind the radiator, a plastic wallet with a bus pass, \
            a photograph of two teenage boys, and a solicitor's letter about a residence \
            order.

            He put it back exactly where it had been and cleaned the room and went home and \
            did not sleep well.

            What Tomas did then was not report it, which was what he was meant to do with \
            anything found behind a radiator. He started leaving two cups. And a second towel, \
            folded, on the chair rather than the rail. And, on the Thursdays, the biscuits \
            from the trolley that nobody counted.

            She never mentioned it, and he never saw her, and the bed was never slept in once \
            in eleven more weeks.

            In March the room went empty. He stripped it, and under the upside-down cup on the \
            towel there was a folded twenty and a note that said, in biro, thank you for the \
            second cup.

            Tomas has worked at the Vandemere for another nine years. He has never told the \
            management, and he still leaves two cups in 4B.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Tomas cleans rooms at the Vandemere and has done 4B forty-one times, where the bed is never slept in but the armchair is worn and there is always one washed cup",
                loadBearing: true,
                entities: ["Tomas", "Ms Halloran", "the Vandemere"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "He works through the possibilities and rules out drugs and an affair, because there is never anything and never a second cup",
                loadBearing: true,
                entities: ["Tomas", "Ms Halloran"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .conflict,
                summary: "In the fifth week he finds a plastic wallet behind the radiator with a bus pass, a photograph of two teenage boys, and a solicitor's letter about a residence order",
                loadBearing: true,
                entities: ["Tomas", "the plastic wallet"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .attempts,
                summary: "He puts it back exactly where it was, does not report it as he is supposed to, and starts leaving two cups, a second towel and the uncounted biscuits",
                loadBearing: true,
                entities: ["Tomas", "Ms Halloran"],
                causedBy: 3,
                isClimax: true
            ),
            CanonicalBeat(
                id: 5,
                component: .resolution,
                summary: "In March the room goes empty and under the cup there is a folded twenty and a note reading thank you for the second cup",
                loadBearing: true,
                entities: ["Tomas", "Ms Halloran", "the note"],
                causedBy: 4
            ),
            CanonicalBeat(
                id: 6,
                component: .consequences,
                summary: "Nine years on Tomas has never told the management and still leaves two cups in 4B",
                loadBearing: true,
                entities: ["Tomas"],
                causedBy: 5
            ),
        ],
        cast: [
            StoryEntity(name: "Tomas", aliases: ["the cleaner", "the housekeeper", "the narrator"], importance: .central),
            StoryEntity(name: "Ms Halloran", aliases: ["Halloran", "the guest", "the woman in 4B"], importance: .central),
            StoryEntity(name: "the plastic wallet", aliases: ["the wallet", "the letter", "the residence order"], importance: .central),
            StoryEntity(name: "the note", aliases: ["a note", "the thank you note"], importance: .supporting),
            StoryEntity(name: "the Vandemere", aliases: ["the hotel"], importance: .incidental),
        ],
        stakes: "Tomas works out what Ms Halloran is hiding and decides the only useful thing is to say nothing and leave a second cup"
    )

    /// The extra usage is not a stranger. It is the person they were already grieving.
    static let meterReading = GuidedStory(
        id: "meter-reading",
        title: "What the Meter Read",
        genre: .mystery,
        prose: """
            The electricity at 14 Kelso Row had been in Fen's name since her father went into \
            the home in April, and the house had been empty since, and the bill in August was \
            for eleven pounds, which is what an empty house costs.

            The bill in September was for ninety-four.

            Fen drove over on the Saturday. Nothing was on. Nothing was warm. The fridge was \
            off at the wall the way she had left it. She read the meter herself, twice, and \
            it agreed with the bill and disagreed with the house.

            She rang the supplier and was told, at length, that the meter was fine. She \
            changed the locks anyway, and then sat in the car outside until half eleven on \
            two separate nights and saw nobody go in or out.

            In October it was a hundred and six.

            What she did in the end was go into the loft, which she had not done, because the \
            hatch was above the landing and her father had put the hatch there and she had \
            been avoiding the landing for six months.

            There was an extension lead running from the socket on the landing up through the \
            hatch. At the end of it, in the loft, was a chest freezer, running, full, and \
            neatly labelled in her father's handwriting: everything he had cooked and frozen \
            across the last two winters before he went into the home. Portions. Dated. \
            Enough, at a glance, for about a year.

            He had never told her. He had been putting it up there since the diagnosis, \
            against the eventuality that she would one day be doing exactly what she was \
            doing, which was standing in his house on her own trying to work out how to feed \
            herself through something.

            Fen turned the freezer off at the end of November, when it was empty.

            She has never told her father that she found it, because by then he would not have \
            known what she was talking about, and she did not want the version of him that \
            didn't to be the one she asked.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "Fen's father is in a home and his house on Kelso Row has been empty since April, costing eleven pounds a month",
                loadBearing: true,
                entities: ["Fen", "her father", "the house"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "The September bill is ninety-four pounds, and when she drives over nothing is on and the meter agrees with the bill",
                loadBearing: true,
                entities: ["Fen", "the meter"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .conflict,
                summary: "The supplier insists the meter is fine, so she changes the locks and watches the house on two nights, seeing nobody",
                loadBearing: true,
                entities: ["Fen", "the house"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .attempts,
                summary: "In October the bill is higher still, so she finally goes up into the loft, which she had been avoiding because the hatch is above the landing",
                loadBearing: true,
                entities: ["Fen", "the house"],
                causedBy: 3
            ),
            CanonicalBeat(
                id: 5,
                component: .resolution,
                summary: "An extension lead runs to a chest freezer full of meals her father cooked, portioned, dated and labelled in his handwriting since his diagnosis — about a year's worth, for her",
                loadBearing: true,
                entities: ["Fen", "her father", "the freezer"],
                causedBy: 4,
                isClimax: true
            ),
            CanonicalBeat(
                id: 6,
                component: .consequences,
                summary: "She turns the freezer off in November when it is empty, and never tells her father, because by then he would not have known what she meant",
                loadBearing: true,
                entities: ["Fen", "her father", "the freezer"],
                causedBy: 5
            ),
        ],
        cast: [
            StoryEntity(name: "Fen", aliases: ["the daughter", "the narrator"], importance: .central),
            StoryEntity(name: "her father", aliases: ["the father", "the old man", "her dad"], importance: .central),
            StoryEntity(name: "the freezer", aliases: ["a chest freezer", "the chest freezer"], importance: .central),
            StoryEntity(name: "the meter", aliases: ["the electricity meter", "the bill", "the electricity bill"], importance: .central),
            StoryEntity(name: "the house", aliases: ["Kelso Row", "the empty house"], importance: .supporting),
        ],
        stakes: "Fen goes looking for an intruder and finds a year of meals her father left her without ever saying so"
    )

    /// The near-misses are deliberate and kind, which is worse to be told than a threat.
    static let cyclistOnFerndale = GuidedStory(
        id: "cyclist-on-ferndale",
        title: "The Cyclist on Ferndale",
        genre: .mystery,
        prose: """
            The first time the cyclist came off the pavement in front of Ottoline's car on \
            Ferndale Road she braked hard enough to put the shopping into the footwell, and \
            she was still shaking at the lights.

            The second time was eight days later, same stretch, same bike, and she saw enough \
            of him to know he was young and wearing a courier bag.

            By the fifth time she had a notebook in the door pocket. Dates, times, weather. \
            Always between four and half four. Always the stretch of Ferndale between the \
            postbox and the school gates. Always exactly far enough in front of her that she \
            had time.

            That was the part she could not get past. She had time, every single time. \
            Whatever he was doing, he was doing it with a margin.

            She reported it twice. The first officer wrote it down. The second one asked, not \
            unkindly, whether she had considered that she might be driving faster than she \
            thought on that stretch.

            So she started leaving earlier, and going the other way round by Lyndhurst, and it \
            stopped, and she felt foolish for about a fortnight.

            Then in June she was on Ferndale at ten past four because of a delivery, and he \
            came off the pavement, and she braked, and this time she got out of the car.

            He was seventeen. He was extremely embarrassed. And what he said, eventually, \
            standing on the pavement holding his bike, was that his little sister was at the \
            school, and that she crossed at the postbox where there was no crossing, and that \
            he had worked out in April that if a car had already braked at the postbox it went \
            through the gates at about eleven miles an hour instead of thirty.

            He had been doing it to every car. Ottoline was one of about nine.

            She drove home by Lyndhurst. She has driven by Lyndhurst ever since, and she has \
            never told anybody at the school, and she still has the notebook.
            """,
        beats: [
            CanonicalBeat(
                id: 1,
                component: .setting,
                summary: "A cyclist rides off the pavement in front of Ottoline's car on Ferndale Road, badly frightening her",
                loadBearing: true,
                entities: ["Ottoline", "the cyclist"],
                causedBy: nil
            ),
            CanonicalBeat(
                id: 2,
                component: .initiatingEvent,
                summary: "It keeps happening on the same stretch, and by the fifth time she is logging dates, times and weather in a notebook",
                loadBearing: true,
                entities: ["Ottoline", "the cyclist", "the notebook"],
                causedBy: 1
            ),
            CanonicalBeat(
                id: 3,
                component: .conflict,
                summary: "What she cannot get past is that he always leaves her exactly enough time — whatever he is doing, he is doing it with a margin",
                loadBearing: true,
                entities: ["Ottoline", "the cyclist"],
                causedBy: 2
            ),
            CanonicalBeat(
                id: 4,
                component: .attempts,
                summary: "She reports it twice, the second officer suggests she may be speeding, so she avoids the road and it stops",
                loadBearing: true,
                entities: ["Ottoline", "the police officer"],
                causedBy: 3
            ),
            CanonicalBeat(
                id: 5,
                component: .resolution,
                summary: "In June she gets out of the car and he explains: his little sister crosses at the postbox where there is no crossing, and a car that has already braked passes the school gates at eleven miles an hour instead of thirty",
                loadBearing: true,
                entities: ["Ottoline", "the cyclist", "his sister"],
                causedBy: 4,
                isClimax: true
            ),
            CanonicalBeat(
                id: 6,
                component: .consequences,
                summary: "He had been doing it to about nine cars, and Ottoline has driven the long way ever since, never telling the school, still keeping the notebook",
                loadBearing: true,
                entities: ["Ottoline", "the notebook"],
                causedBy: 5
            ),
        ],
        cast: [
            StoryEntity(name: "Ottoline", aliases: ["the driver", "the woman", "the narrator"], importance: .central),
            StoryEntity(name: "the cyclist", aliases: ["the boy", "the courier", "the seventeen-year-old"], importance: .central),
            StoryEntity(name: "his sister", aliases: ["the little sister", "the girl", "the schoolgirl"], importance: .central),
            StoryEntity(name: "the notebook", aliases: ["a notebook", "the log"], importance: .supporting),
            StoryEntity(name: "the police officer", aliases: ["the officer", "the police"], importance: .supporting),
        ],
        stakes: "Ottoline spent months building a case against somebody who was slowing cars down outside his sister's school"
    )
}
