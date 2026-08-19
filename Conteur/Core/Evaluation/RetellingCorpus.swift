import Foundation

/// Retellings written to a known answer, one shape at a time.
///
/// The expected coverage is deliberately generous about wording and strict about content: a
/// beat counts as covered if a listener would say the event came through, however it was
/// phrased. That is the standard the model is being held to, so it is the standard the
/// corpus is written to.
enum RetellingCorpus {
    static let all: [RetellingSample] = thirdCast + houseKept + nineFifteen

    // MARK: - The Third Cast (7 beats)

    static let thirdCast: [RetellingSample] = [
        RetellingSample(
            storyID: "third-cast",
            shape: .faithful,
            spoken: """
                So this is about a fisherman called Aren who lived with his daughter Mira \
                near the sea, and he'd fished there thirty years and always just about got \
                by. Then his nets came up completely empty for eleven days running and they \
                ended up eating nettles. On the twelfth day he pulls up a silver fish and it \
                talks to him, and it says it'll fill his net once. So he asks for that, and \
                it works, and he sells the catch. But he goes back the next day and asks for \
                a bigger boat, and then the biggest boat in the whole town. And then on the \
                fourth day he asks for the entire sea, every fish in it, forever. And the \
                water just goes completely still, and when he gets home everything's gone. \
                The boats, the food, all of it. Mira just hands him a needle, and he goes \
                back to mending nets for another thirty years. And I think the point is he \
                already had enough, and it was asking for everything that took it off him.
                """,
            expectedBeats: [1, 2, 3, 4, 5, 6, 7],
            expectedStakes: true
        ),
        RetellingSample(
            storyID: "third-cast",
            shape: .partial,
            spoken: """
                It's about a fisherman, Aren, who lives with his daughter by the sea and \
                they're poor but they manage. And then for about a week and a half his nets \
                come up with nothing at all, and they're reduced to eating nettles off the \
                hillside. And then one morning there's this silver fish in the net and it \
                actually speaks to him. That's about as far as I got with it really.
                """,
            expectedBeats: [1, 2, 3],
            expectedStakes: false
        ),
        RetellingSample(
            storyID: "third-cast",
            shape: .scrambled,
            spoken: """
                Right, so at the end he's mending nets again and his daughter gives him the \
                needle. Before that the sea goes flat and everything he'd got disappears. He'd \
                asked for the whole sea by that point. But going back, he'd asked for the \
                biggest boat in the town, and before that a bigger boat, and the first thing \
                he ever asked the fish for was just a full net. The fish turned up in his net \
                after eleven days of catching nothing. He's a fisherman, Aren, thirty years \
                at it, lives with Mira his daughter.
                """,
            expectedBeats: [1, 2, 3, 4, 5, 6, 7],
            expectedStakes: false
        ),
        RetellingSample(
            storyID: "third-cast",
            shape: .commentary,
            spoken: """
                It's one of those fishing ones. Aren, I think he was called. Honestly I \
                thought it was quite bleak? Like the daughter Mira doesn't really get a say \
                in any of it, which annoyed me a bit. And the sea is obviously meant to be a \
                sort of moral thing. I don't know, it felt a bit old fashioned to me. Nice \
                writing though. What did you think of it?
                """,
            expectedBeats: [],
            expectedStakes: false
        ),
        RetellingSample(
            storyID: "third-cast",
            shape: .paraphrased,
            spoken: """
                Right, an old man who'd worked the water for decades, scraping along with \
                his girl in a cottage up top. Everything dries up on him — a week and a half, \
                nothing in the mesh, down to boiling weeds for supper. Then a shining thing \
                turns up and starts speaking, offers him one favour. First he wants his catch, \
                and gets it, and it sells. Greed sets in — he wants a vessel, then the finest \
                vessel anywhere. Fourth trip out he demands the whole ocean, permanently. \
                Everything reverses. Flat water, and back at the cottage nothing left but the \
                girl and ruined mesh. She passes him a bit of steel and thread, and he's back \
                where he began for another few decades.
                """,
            expectedBeats: [1, 2, 3, 4, 5, 6, 7],
            expectedStakes: false
        ),
        RetellingSample(
            storyID: "third-cast",
            shape: .invented,
            spoken: """
                So Aren is a fisherman, thirty years, lives with his daughter Mira. His nets \
                come up empty for eleven days and they're eating nettles. Then he catches a \
                silver fish that talks and offers to fill his net, and he takes it. His \
                brother Callum tells him to go back and ask for more, so he does — a bigger \
                boat, then the biggest boat in Coldhaven. Then he asks for the whole sea. And \
                the water goes still and he loses everything, and Mira hands him a needle and \
                he's back to mending nets for thirty years.
                """,
            expectedBeats: [1, 2, 3, 4, 5, 6, 7],
            expectedStakes: false
        ),
    ]

    // MARK: - What the House Kept (5 beats)

    static let houseKept: [RetellingSample] = [
        RetellingSample(
            storyID: "what-the-house-kept",
            shape: .faithful,
            spoken: """
                This one's about a woman called Nadia clearing out her mum's house after she \
                died, because the estate agent wants it empty by the end of the month and \
                there's nobody else to do it. And she's nearly finished when she opens the \
                bottom drawer of the writing desk and it's full of letters — about sixty of \
                them, all in her mother's handwriting, and every single one has been sent \
                back unopened. They're addressed to Rosalind, who turns out to be her \
                mother's sister, and Nadia had never once heard that name in her entire \
                childhood. So she's sitting there realising she's got two choices and both of \
                them are permanent — bin them and keep the family the size it's always been, \
                or ring the number and turn a stranger into an aunt. And what she actually \
                does is write the number on the back of her hand instead of in her phone, \
                which she knows means she can wash it off. That's what got me — she can end \
                a sixty-year silence or let it close over, and she leaves herself the out.
                """,
            expectedBeats: [1, 2, 3, 4, 5],
            expectedStakes: true
        ),
        RetellingSample(
            storyID: "what-the-house-kept",
            shape: .partial,
            spoken: """
                So there's a woman, Nadia, and her mother has died and she's on her own \
                emptying the house because the estate agent needs it done. Her mum was very \
                tidy, everything in its place. And then she finds this drawer that's heavier \
                than the rest and it's absolutely full of letters, dozens of them, and they've \
                all come back unopened. And I think that's where I stopped taking it in \
                properly, to be honest.
                """,
            expectedBeats: [1, 2],
            expectedStakes: false
        ),
        RetellingSample(
            storyID: "what-the-house-kept",
            shape: .commentary,
            spoken: """
                The house one. Nadia. I found it quite sad actually, more than the others. \
                She's kept that house all to herself, hasn't she, and she doesn't really want \
                to let it go. I don't blame her, it sounds like a nice house. I wasn't sure \
                what to make of the mother. Anyway, yeah, that one stayed with me a bit.
                """,
            expectedBeats: [],
            expectedStakes: false
        ),
        RetellingSample(
            storyID: "what-the-house-kept",
            shape: .invented,
            spoken: """
                Nadia is clearing her mother Elspeth's house after the funeral, with the \
                estate agent waiting. She finds sixty letters in the writing desk, all \
                returned unopened, addressed to Rosalind — her mother's sister, never once \
                mentioned. Her husband Daniel tells her to throw them out. She realises it's \
                either bin them or call Cork and gain an aunt, and in the end she writes the \
                number on her hand rather than her phone.
                """,
            expectedBeats: [1, 2, 3, 4, 5],
            expectedStakes: false
        ),
    ]

    // MARK: - The Nine-Fifteen (6 beats)

    static let nineFifteen: [RetellingSample] = [
        RetellingSample(
            storyID: "the-nine-fifteen",
            shape: .faithful,
            spoken: """
                So Priya gets the same train every morning, the nine-fifteen, and there's a \
                man in a grey overcoat who's been on it with her for about a year. And in \
                October she notices he's carrying a different briefcase every single day — \
                never the same one twice, she counts nineteen of them by Christmas. And it \
                gets under her skin, she starts sitting where she can watch him, and then one \
                morning in January she just follows him instead of going to work. He goes down \
                a service lane behind some shops and in through a door, and she's stood out \
                there with her phone in her hand working out what to tell the police. And then \
                a woman comes out crying holding one of the cases, and the sign on the door \
                says lost property. He's a volunteer. He's been taking cases people left on \
                the tube back to them, twice a week, for six years. And she never says a word \
                to him about it, and for the last four months they're on that train together \
                she can't even look at him. Which is the whole thing really — all of it was \
                about her, none of it was about him.
                """,
            expectedBeats: [1, 2, 3, 4, 5, 6],
            expectedStakes: true
        ),
        RetellingSample(
            storyID: "the-nine-fifteen",
            shape: .partial,
            spoken: """
                Priya's on the nine-fifteen every day and there's this bloke in a grey coat \
                who gets off at her stop. And she clocks that he's got a different briefcase \
                every morning, which is odd, and she starts counting them — nineteen by \
                Christmas or something. And it really starts bothering her, she can't leave it \
                alone, she's moving seats so she can watch him. And then in January she \
                follows him off the train. And that's about where I ran out.
                """,
            expectedBeats: [1, 2, 3],
            expectedStakes: false
        ),
        RetellingSample(
            storyID: "the-nine-fifteen",
            shape: .scrambled,
            spoken: """
                The ending is she can't look at him for the last four months on the train. \
                Before that she finds out he's a lost property volunteer, six years of it, \
                and a woman comes out crying with one of the cases. She'd been stood in a \
                service lane with her phone out ready to ring the police. She'd followed him \
                off the train that January. The reason was the briefcases — a different one \
                every morning, nineteen by Christmas. And he's just a man in a grey overcoat \
                she'd shared the nine-fifteen with for a year.
                """,
            expectedBeats: [1, 2, 3, 4, 5, 6],
            expectedStakes: false
        ),
        RetellingSample(
            storyID: "the-nine-fifteen",
            shape: .paraphrased,
            spoken: """
                A commuter and a fellow passenger, same service, twelve months or so. She \
                clocks that his luggage changes daily — never repeats, and she tallies about \
                twenty before the holidays. It becomes an obsession. She relocates seats for a \
                better view, and one winter morning abandons her own journey to trail him. Down \
                an alley, through a doorway; she loiters outside composing a call to the \
                authorities. Someone emerges in tears clutching one of the items. The premises \
                turn out to handle mislaid belongings. He gives his time there, unpaid, and has \
                done for six years, reuniting people with what they left behind. She keeps all \
                of it to herself and cannot meet his eye for the rest of their shared \
                commute.
                """,
            expectedBeats: [1, 2, 3, 4, 5, 6],
            expectedStakes: false
        ),
        RetellingSample(
            storyID: "the-nine-fifteen",
            shape: .commentary,
            spoken: """
                That was the train one. I liked it more than I expected. Priya's quite hard to \
                like though isn't she, following a stranger around. I did think the writing was \
                good. The bit at the end is meant to make you feel bad I think. I'm not sure I \
                totally bought that he'd been doing it for six years without anyone noticing. \
                Anyway. Good one.
                """,
            expectedBeats: [],
            expectedStakes: false
        ),
    ]
}
