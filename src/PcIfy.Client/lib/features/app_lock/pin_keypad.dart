import 'package:flutter/material.dart';

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  static const _keys = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '',  '0', '<',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: _keys.map((key) {
        if (key.isEmpty) return const SizedBox.shrink();
        if (key == '<') {
          return _KeyButton(
            onTap: onBackspace,
            child: const Icon(Icons.backspace_outlined, size: 22),
          );
        }
        return _KeyButton(
          onTap: () => onDigit(key),
          child: Text(key,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w400)),
        );
      }).toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Center(child: child),
    );
  }
}
