import SwiftUI

struct StickerPicker: View {
    let onPick: (String) -> Void
    @State private var typed = ""

    private static let sets: [(String, String)] = [
        ("party", "🎉🥳🎂🎈🎁🪩🍾🥂🎊🪅🕺💃🎤🎶✨⭐️🌟💫"),
        ("love", "💖💕💌💘💝❤️🩷🧡💛💚🩵💙💜🖤🤍💋🌹🫶"),
        ("cute", "🎀🌸🌷🌼🌺🦋🐣🧸🍓🍒🧁🍰🫧☁️🌈🐰🐻‍❄️🦢"),
        ("food", "🍕🌮🍔🍟🌭🍿🍩🍪🍦🍉🍋🥑🍣🍜🧀🥐☕️🍷"),
        ("nowruz", "🌱🐠🪻🍎🪙🥚🕯️🪞🌷🍬🧄🌿🔥🌞"),
        ("outdoors", "🏔️⛷️🏂🎿❄️☃️🏖️🏊🌴🦩🕶️🚐🌵🗺️⛽🏕️🌊⛺️"),
        ("silly", "🦖🤠🤡👽🤖💀🫠🙃🐸🦆🦄🐙🍄🧌👀🫡🗿🤯"),
        ("things", "🎓📚🎲🃏♟️🎮🏆🎯🍼👶🏡🗝️💐🎨📸🎸🛼⚽️"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    TextField("type any emoji", text: $typed)
                        .padding(12).glassEffect(in: .rect(cornerRadius: 14))
                        .onSubmit(submit)
                    Button("Add", action: submit).buttonStyle(.glassProminent).disabled(typed.isEmpty)
                }
                ForEach(Self.sets, id: \.0) { name, emojis in
                    Text(name).font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(Array(emojis).map(String.init), id: \.self) { e in
                            Button { onPick(e) } label: { Text(e).font(.system(size: 36)) }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func submit() {
        guard let last = typed.last else { return }
        onPick(String(last))
        typed = ""
    }
}
