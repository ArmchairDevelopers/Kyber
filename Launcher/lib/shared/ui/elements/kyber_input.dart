import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';

class KyberInput extends StatefulWidget {
  const KyberInput({
    super.key,
    this.placeholder,
    this.controller,
    this.onChanged,
    this.onFieldSubmitted,
    this.focusNode,
    this.autofocus,
    this.initialValue,
    this.filled = false,
    this.disabled = false,
    this.isSensitive = false,
    this.validator,
    this.suffix,
  });

  final String? placeholder;
  final String? initialValue;
  final bool? autofocus;
  final bool? filled;
  final bool? isSensitive;
  final bool disabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  State<KyberInput> createState() => _KyberInputState();
}

class _KyberInputState extends State<KyberInput> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: Colors.black.withOpacity(.6),
        child: mt.TextFormField(
          initialValue: widget.initialValue,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          autofocus: widget.autofocus ?? false,
          focusNode: widget.focusNode,
          controller: widget.controller,
          validator: widget.validator,
          style: const mt.TextStyle(
            color: kWhiteColor,
            fontFamily: FontFamily.battlefrontUI,
            fontSize: 15,
            height: 1,
          ),
          obscureText: widget.isSensitive ?? false,
          decoration: mt.InputDecoration(
            errorStyle: const TextStyle(
              fontFamily: FontFamily.battlefrontUI,
              fontSize: 15,
            ),
            filled: widget.filled,
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
              vertical: widget.validator != null ? 15.5 : 13.5,
            ),
            suffixIcon: widget.suffix,
            enabled: !widget.disabled,
            hintText: widget.placeholder?.toUpperCase() ?? '',
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
