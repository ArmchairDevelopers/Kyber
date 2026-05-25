import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';

class KyberFormInputField extends StatelessWidget {
  const KyberFormInputField({
    required this.name,
    super.key,
    this.validator,
    this.placeholder,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.onFieldSubmitted,
    this.focusNode,
    this.autofocus,
    this.isSensitive = false,
    this.filled = false,
    this.disabled = false,
    this.suffix,
  });

  final String name;
  final String? initialValue;
  final String? Function(String?)? validator;
  final String? placeholder;
  final bool? autofocus;
  final bool? filled;
  final bool? isSensitive;
  final bool disabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String?>? onChanged;
  final TextEditingController? controller;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: Colors.black.withOpacity(.6),
        child: FormBuilderTextField(
          name: name,
          validator: validator,
          initialValue: initialValue,
          onChanged: onChanged,
          autofocus: autofocus ?? false,
          focusNode: focusNode,
          controller: controller,
          style: const mt.TextStyle(
            fontFamily: FontFamily.battlefrontUI,
            fontSize: 15,
            height: 1,
          ),
          obscureText: isSensitive ?? false,
          decoration: mt.InputDecoration(
            errorStyle: const TextStyle(
              fontFamily: FontFamily.battlefrontUI,
              fontSize: 15,
            ),
            filled: filled,
            fillColor: kInactiveColor.withOpacity(.05),
            isDense: true,
            enabledBorder: mt.OutlineInputBorder(
              borderSide: const mt.BorderSide(color: decoColor, width: 2),
              borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius),
            ),
            focusedBorder: mt.OutlineInputBorder(
              borderSide: mt.BorderSide(color: kActiveColor, width: 2),
              borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: validator != null ? 15.5 : 12.5,
            ),
            suffixIcon: suffix,
            enabled: !disabled,
            hintText: placeholder?.toUpperCase() ?? '',
            hintStyle: const TextStyle(
              color: kInactiveColor,
              fontSize: 15,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
