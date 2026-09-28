import 'package:flutter/material.dart';

class CertificateField {
  const CertificateField({required this.id, required this.placeholder, required this.x, required this.y, this.width = 0.45, this.height = 0.09, this.fontFamily = 'Helvetica', this.fontSize = 28, this.color = 0xFF183B4E, this.fontWeight = FontWeight.w600, this.alignment = TextAlign.center});
  final String id;
  final String placeholder;
  final double x;
  final double y;
  final double width;
  final double height;
  final String fontFamily;
  final double fontSize;
  final int color;
  final FontWeight fontWeight;
  final TextAlign alignment;

  CertificateField copyWith({
    String? id,
    String? placeholder,
    double? x,
    double? y,
    double? width,
    double? height,
    String? fontFamily,
    double? fontSize,
    int? color,
    FontWeight? fontWeight,
    TextAlign? alignment,
  }) =>
      CertificateField(
        id: id ?? this.id,
        placeholder: placeholder ?? this.placeholder,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        color: color ?? this.color,
        fontWeight: fontWeight ?? this.fontWeight,
        alignment: alignment ?? this.alignment,
      );

  Map<String, dynamic> toJson() => {'id': id, 'placeholder': placeholder, 'x': x, 'y': y, 'width': width, 'height': height, 'fontFamily': fontFamily, 'fontSize': fontSize, 'color': color, 'fontWeight': fontWeight.value, 'alignment': alignment.index};
  factory CertificateField.fromJson(Map<String, dynamic> json) => CertificateField(
        id: json['id'] as String,
        placeholder: json['placeholder'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num?)?.toDouble() ?? 0.45,
        height: (json['height'] as num?)?.toDouble() ?? 0.09,
        fontFamily: json['fontFamily'] as String? ?? 'Helvetica',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 28,
        color: json['color'] as int? ?? 0xFF183B4E,
        fontWeight: FontWeight.values.firstWhere((weight) => weight.value == (json['fontWeight'] as int? ?? FontWeight.w600.value)),
        alignment: TextAlign.values[json['alignment'] as int? ?? TextAlign.center.index],
      );
}