import 'package:flutter/material.dart';

const List<String> kEmojiAvatars = <String>[
  '🙂',
  '😎',
  '🧑‍💻',
  '👩‍🔧',
  '🧑‍🚒',
  '👨‍🔧',
  '👩‍💻',
  '🚧',
  '🏗',
  '🧑‍🔧',
];

class EmojiAvatarPicker extends StatelessWidget {
  const EmojiAvatarPicker({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CircleAvatar(
            radius: 36,
            child: Text(
              selected.isEmpty ? '🙂' : selected,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kEmojiAvatars.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (BuildContext context, int index) {
            final String emoji = kEmojiAvatars[index];
            final bool isSelected = selected == emoji;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
<<<<<<< HEAD
                      : Colors.white,
=======
                      : Theme.of(context).colorScheme.surface,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
