import 'package:flutter/material.dart';

/// RadioGroup 위젯
/// RadioListTile을 그룹으로 관리하는 위젯
class RadioGroup<T> extends StatelessWidget {
  final T? groupValue;
  final ValueChanged<T?> onChanged;
  final Widget child;

  const RadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
  
  /// RadioGroup에서 사용할 RadioListTile을 생성하는 헬퍼 메서드
  static Widget tile<T>({
    required T value,
    required T? groupValue,
    required ValueChanged<T?> onChanged,
    required Widget title,
  }) {
    return RadioListTile<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: title,
    );
  }
}

