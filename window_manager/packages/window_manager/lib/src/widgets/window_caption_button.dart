// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

const _kIconChromeClose = 'icon_chrome_close';
const _kIconChromeMaximize = 'icon_chrome_maximize';
const _kIconChromeMinimize = 'icon_chrome_minimize';
const _kIconChromeUnmaximize = 'icon_chrome_unmaximize';

class _IconChromeMinimizePainter extends CustomPainter {
  _IconChromeMinimizePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(3.49805, 8)
      ..cubicTo(3.42969, 8, 3.36458, 7.98698, 3.30273, 7.96094)
      ..cubicTo(3.24414, 7.9349, 3.19206, 7.89909, 3.14648, 7.85352)
      ..cubicTo(3.10091, 7.80794, 3.0651, 7.75586, 3.03906, 7.69727)
      ..cubicTo(3.01302, 7.63542, 3, 7.57031, 3, 7.50195)
      ..cubicTo(3, 7.43359, 3.01302, 7.37012, 3.03906, 7.31152)
      ..cubicTo(3.0651, 7.24967, 3.10091, 7.19596, 3.14648, 7.15039)
      ..cubicTo(3.19206, 7.10156, 3.24414, 7.06413, 3.30273, 7.03809)
      ..cubicTo(3.36458, 7.01204, 3.42969, 6.99902, 3.49805, 6.99902)
      ..lineTo(12.502, 6.99902)
      ..cubicTo(12.5703, 6.99902, 12.6338, 7.01204, 12.6924, 7.03809)
      ..cubicTo(12.7542, 7.06413, 12.8079, 7.10156, 12.8535, 7.15039)
      ..cubicTo(12.8991, 7.19596, 12.9349, 7.24967, 12.9609, 7.31152)
      ..cubicTo(12.987, 7.37012, 13, 7.43359, 13, 7.50195)
      ..cubicTo(13, 7.57031, 12.987, 7.63542, 12.9609, 7.69727)
      ..cubicTo(12.9349, 7.75586, 12.8991, 7.80794, 12.8535, 7.85352)
      ..cubicTo(12.8079, 7.89909, 12.7542, 7.9349, 12.6924, 7.96094)
      ..cubicTo(12.6338, 7.98698, 12.5703, 8, 12.502, 8)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _IconChromeMaximizePainter extends CustomPainter {
  _IconChromeMaximizePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Path path = Path()
      ..moveTo(4.47461, 13)
      ..cubicTo(4.2793, 13, 4.09212, 12.9609, 3.91309, 12.8828)
      ..cubicTo(3.73405, 12.8014, 3.57617, 12.694, 3.43945, 12.5605)
      ..cubicTo(3.30599, 12.4238, 3.19857, 12.266, 3.11719, 12.0869)
      ..cubicTo(3.03906, 11.9079, 3, 11.7207, 3, 11.5254)
      ..lineTo(3, 4.47461)
      ..cubicTo(3, 4.2793, 3.03906, 4.09212, 3.11719, 3.91309)
      ..cubicTo(3.19857, 3.73405, 3.30599, 3.5778, 3.43945, 3.44434)
      ..cubicTo(3.57617, 3.30762, 3.73405, 3.2002, 3.91309, 3.12207)
      ..cubicTo(4.09212, 3.04069, 4.2793, 3, 4.47461, 3)
      ..lineTo(11.5254, 3)
      ..cubicTo(11.7207, 3, 11.9079, 3.04069, 12.0869, 3.12207)
      ..cubicTo(12.266, 3.2002, 12.4222, 3.30762, 12.5557, 3.44434)
      ..cubicTo(12.6924, 3.5778, 12.7998, 3.73405, 12.8779, 3.91309)
      ..cubicTo(12.9593, 4.09212, 13, 4.2793, 13, 4.47461)
      ..lineTo(13, 11.5254)
      ..cubicTo(13, 11.7207, 12.9593, 11.9079, 12.8779, 12.0869)
      ..cubicTo(12.7998, 12.266, 12.6924, 12.4238, 12.5557, 12.5605)
      ..cubicTo(12.4222, 12.694, 12.266, 12.8014, 12.0869, 12.8828)
      ..cubicTo(11.9079, 12.9609, 11.7207, 13, 11.5254, 13)
      ..lineTo(4.47461, 13)
      ..moveTo(11.501, 11.999)
      ..cubicTo(11.5693, 11.999, 11.6328, 11.986, 11.6914, 11.96)
      ..cubicTo(11.7533, 11.9339, 11.807, 11.8981, 11.8525, 11.8525)
      ..cubicTo(11.8981, 11.807, 11.9339, 11.7549, 11.96, 11.6963)
      ..cubicTo(11.986, 11.6344, 11.999, 11.5693, 11.999, 11.501)
      ..lineTo(11.999, 4.49902)
      ..cubicTo(11.999, 4.43066, 11.986, 4.36719, 11.96, 4.30859)
      ..cubicTo(11.9339, 4.24674, 11.8981, 4.19303, 11.8525, 4.14746)
      ..cubicTo(11.807, 4.10189, 11.7533, 4.06608, 11.6914, 4.04004)
      ..cubicTo(11.6328, 4.014, 11.5693, 4.00098, 11.501, 4.00098)
      ..lineTo(4.49902, 4.00098)
      ..cubicTo(4.43066, 4.00098, 4.36556, 4.014, 4.30371, 4.04004)
      ..cubicTo(4.24512, 4.06608, 4.19303, 4.10189, 4.14746, 4.14746)
      ..cubicTo(4.10189, 4.19303, 4.06608, 4.24674, 4.04004, 4.30859)
      ..cubicTo(4.014, 4.36719, 4.00098, 4.43066, 4.00098, 4.49902)
      ..lineTo(4.00098, 11.501)
      ..cubicTo(4.00098, 11.5693, 4.014, 11.6344, 4.04004, 11.6963)
      ..cubicTo(4.06608, 11.7549, 4.10189, 11.807, 4.14746, 11.8525)
      ..cubicTo(4.19303, 11.8981, 4.24512, 11.9339, 4.30371, 11.96)
      ..cubicTo(4.36556, 11.986, 4.43066, 11.999, 4.49902, 11.999)
      ..lineTo(11.501, 11.999)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _IconChromeUnmaximizePainter extends CustomPainter {
  _IconChromeUnmaximizePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(11.999, 5.96387)
      ..cubicTo(11.999, 5.69368, 11.9453, 5.43978, 11.8379, 5.20215)
      ..cubicTo(11.7305, 4.96126, 11.584, 4.75293, 11.3984, 4.57715)
      ..cubicTo(11.2161, 4.39811, 11.0029, 4.25814, 10.7588, 4.15723)
      ..cubicTo(10.5179, 4.05306, 10.264, 4.00098, 9.99707, 4.00098)
      ..lineTo(5.08496, 4.00098)
      ..cubicTo(5.13704, 3.85124, 5.21029, 3.71452, 5.30469, 3.59082)
      ..cubicTo(5.39909, 3.46712, 5.50814, 3.36133, 5.63184, 3.27344)
      ..cubicTo(5.75553, 3.18555, 5.89062, 3.11882, 6.03711, 3.07324)
      ..cubicTo(6.18685, 3.02441, 6.34147, 3, 6.50098, 3)
      ..lineTo(9.99707, 3)
      ..cubicTo(10.4105, 3, 10.7995, 3.07975, 11.1641, 3.23926)
      ..cubicTo(11.5286, 3.39551, 11.846, 3.60872, 12.1162, 3.87891)
      ..cubicTo(12.3896, 4.14909, 12.6045, 4.46647, 12.7607, 4.83105)
      ..cubicTo(12.9202, 5.19564, 13, 5.58464, 13, 5.99805)
      ..lineTo(13, 9.49902)
      ..cubicTo(13, 9.65853, 12.9756, 9.81315, 12.9268, 9.96289)
      ..cubicTo(12.8812, 10.1094, 12.8145, 10.2445, 12.7266, 10.3682)
      ..cubicTo(12.6387, 10.4919, 12.5329, 10.6009, 12.4092, 10.6953)
      ..cubicTo(12.2855, 10.7897, 12.1488, 10.863, 11.999, 10.915)
      ..lineTo(11.999, 5.96387)
      ..close()
      ..moveTo(4.47461, 13)
      ..cubicTo(4.2793, 13, 4.09212, 12.9609, 3.91309, 12.8828)
      ..cubicTo(3.73405, 12.8014, 3.57617, 12.694, 3.43945, 12.5605)
      ..cubicTo(3.30599, 12.4238, 3.19857, 12.266, 3.11719, 12.0869)
      ..cubicTo(3.03906, 11.9079, 3, 11.7207, 3, 11.5254)
      ..lineTo(3, 6.47656)
      ..cubicTo(3, 6.27799, 3.03906, 6.09082, 3.11719, 5.91504)
      ..cubicTo(3.19857, 5.736, 3.30599, 5.57975, 3.43945, 5.44629)
      ..cubicTo(3.57617, 5.30957, 3.73242, 5.20215, 3.9082, 5.12402)
      ..cubicTo(4.08724, 5.04264, 4.27604, 5.00195, 4.47461, 5.00195)
      ..lineTo(9.52344, 5.00195)
      ..cubicTo(9.72201, 5.00195, 9.91081, 5.04264, 10.0898, 5.12402)
      ..cubicTo(10.2689, 5.20215, 10.4251, 5.30794, 10.5586, 5.44141)
      ..cubicTo(10.6921, 5.57487, 10.7979, 5.73112, 10.876, 5.91016)
      ..cubicTo(10.9574, 6.08919, 10.998, 6.27799, 10.998, 6.47656)
      ..lineTo(10.998, 11.5254)
      ..cubicTo(10.998, 11.724, 10.9574, 11.9128, 10.876, 12.0918)
      ..cubicTo(10.7979, 12.2676, 10.6904, 12.4238, 10.5537, 12.5605)
      ..cubicTo(10.4202, 12.694, 10.264, 12.8014, 10.085, 12.8828)
      ..cubicTo(9.90918, 12.9609, 9.72201, 13, 9.52344, 13)
      ..lineTo(4.47461, 13)
      ..close()
      ..moveTo(9.49902, 11.999)
      ..cubicTo(9.56738, 11.999, 9.63086, 11.986, 9.68945, 11.96)
      ..cubicTo(9.7513, 11.9339, 9.80501, 11.8981, 9.85059, 11.8525)
      ..cubicTo(9.89941, 11.807, 9.93685, 11.7549, 9.96289, 11.6963)
      ..cubicTo(9.98893, 11.6344, 10.002, 11.5693, 10.002, 11.501)
      ..lineTo(10.002, 6.50098)
      ..cubicTo(10.002, 6.43262, 9.98893, 6.36751, 9.96289, 6.30566)
      ..cubicTo(9.93685, 6.24382, 9.90104, 6.1901, 9.85547, 6.14453)
      ..cubicTo(9.8099, 6.09896, 9.75618, 6.06315, 9.69434, 6.03711)
      ..cubicTo(9.63249, 6.01107, 9.56738, 5.99805, 9.49902, 5.99805)
      ..lineTo(4.49902, 5.99805)
      ..cubicTo(4.43066, 5.99805, 4.36556, 6.01107, 4.30371, 6.03711)
      ..cubicTo(4.24512, 6.06315, 4.19303, 6.10059, 4.14746, 6.14941)
      ..cubicTo(4.10189, 6.19499, 4.06608, 6.2487, 4.04004, 6.31055)
      ..cubicTo(4.014, 6.36914, 4.00098, 6.43262, 4.00098, 6.50098)
      ..lineTo(4.00098, 11.501)
      ..cubicTo(4.00098, 11.5693, 4.014, 11.6344, 4.04004, 11.6963)
      ..cubicTo(4.06608, 11.7549, 4.10189, 11.807, 4.14746, 11.8525)
      ..cubicTo(4.19303, 11.8981, 4.24512, 11.9339, 4.30371, 11.96)
      ..cubicTo(4.36556, 11.986, 4.43066, 11.999, 4.49902, 11.999)
      ..lineTo(9.49902, 11.999)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _IconChromeClosePainter extends CustomPainter {
  _IconChromeClosePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(8, 8.70801)
      ..lineTo(3.85449, 12.8535)
      ..cubicTo(3.75684, 12.9512, 3.63965, 13, 3.50293, 13)
      ..cubicTo(3.3597, 13, 3.23926, 12.9528, 3.1416, 12.8584)
      ..cubicTo(3.0472, 12.7607, 3, 12.6403, 3, 12.4971)
      ..cubicTo(3, 12.3604, 3.04883, 12.2432, 3.14648, 12.1455)
      ..lineTo(7.29199, 8)
      ..lineTo(3.14648, 3.85449)
      ..cubicTo(3.04883, 3.75684, 3, 3.63802, 3, 3.49805)
      ..cubicTo(3, 3.42969, 3.01302, 3.36458, 3.03906, 3.30273)
      ..cubicTo(3.0651, 3.24089, 3.10091, 3.1888, 3.14648, 3.14648)
      ..cubicTo(3.19206, 3.10091, 3.24577, 3.0651, 3.30762, 3.03906)
      ..cubicTo(3.36947, 3.01302, 3.43457, 3, 3.50293, 3)
      ..cubicTo(3.63965, 3, 3.75684, 3.04883, 3.85449, 3.14648)
      ..lineTo(8, 7.29199)
      ..lineTo(12.1455, 3.14648)
      ..cubicTo(12.2432, 3.04883, 12.362, 3, 12.502, 3)
      ..cubicTo(12.5703, 3, 12.6338, 3.01302, 12.6924, 3.03906)
      ..cubicTo(12.7542, 3.0651, 12.8079, 3.10091, 12.8535, 3.14648)
      ..cubicTo(12.8991, 3.19206, 12.9349, 3.24577, 12.9609, 3.30762)
      ..cubicTo(12.987, 3.36621, 13, 3.42969, 13, 3.49805)
      ..cubicTo(13, 3.63802, 12.9512, 3.75684, 12.8535, 3.85449)
      ..lineTo(8.70801, 8)
      ..lineTo(12.8535, 12.1455)
      ..cubicTo(12.9512, 12.2432, 13, 12.3604, 13, 12.4971)
      ..cubicTo(13, 12.5654, 12.987, 12.6305, 12.9609, 12.6924)
      ..cubicTo(12.9349, 12.7542, 12.8991, 12.8079, 12.8535, 12.8535)
      ..cubicTo(12.8112, 12.8991, 12.7591, 12.9349, 12.6973, 12.9609)
      ..cubicTo(12.6354, 12.987, 12.5703, 13, 12.502, 13)
      ..cubicTo(12.362, 13, 12.2432, 12.9512, 12.1455, 12.8535)
      ..lineTo(8, 8.70801)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class WindowCaptionButtonIcon extends StatelessWidget {
  const WindowCaptionButtonIcon({
    super.key,
    this.color,
    required this.createPainter,
  });

  final Color? color;
  final CustomPainter Function(Color? color) createPainter;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: createPainter(color),
      size: const Size(16, 16),
    );
  }
}

// ignore: must_be_immutable
class WindowCaptionButton extends StatefulWidget {
  WindowCaptionButton({
    super.key,
    this.brightness,
    this.icon,
    this.iconName,
    required this.onPressed,
  });

  WindowCaptionButton.minimize({
    super.key,
    this.brightness,
    this.icon,
    this.onPressed,
  }) : iconName = _kIconChromeMinimize;

  WindowCaptionButton.maximize({
    super.key,
    this.brightness,
    this.icon,
    this.onPressed,
  }) : iconName = _kIconChromeMaximize;

  WindowCaptionButton.unmaximize({
    super.key,
    this.brightness,
    this.icon,
    this.onPressed,
  }) : iconName = _kIconChromeUnmaximize;

  WindowCaptionButton.close({
    super.key,
    this.brightness,
    this.icon,
    this.onPressed,
  })  : iconName = _kIconChromeClose,
        _lightButtonBgColorScheme = _ButtonBgColorScheme(
          normal: Colors.transparent,
          hovered: const Color(0xffC42B1C),
          pressed: const Color(0xffC42B1C).withValues(alpha: 0.9),
        ),
        _lightButtonIconColorScheme = _ButtonIconColorScheme(
          normal: Colors.black.withValues(alpha: 0.8956),
          hovered: Colors.white,
          pressed: Colors.white.withValues(alpha: 0.7),
          disabled: Colors.black.withValues(alpha: 0.3614),
        ),
        _darkButtonBgColorScheme = _ButtonBgColorScheme(
          normal: Colors.transparent,
          hovered: const Color(0xffC42B1C),
          pressed: const Color(0xffC42B1C).withValues(alpha: 0.9),
        ),
        _darkButtonIconColorScheme = _ButtonIconColorScheme(
          normal: Colors.white,
          hovered: Colors.white,
          pressed: Colors.white.withValues(alpha: 0.786),
          disabled: Colors.black.withValues(alpha: 0.3628),
        );

  final Brightness? brightness;
  final Widget? icon;
  final String? iconName;
  final VoidCallback? onPressed;

  _ButtonBgColorScheme _lightButtonBgColorScheme = _ButtonBgColorScheme(
    normal: Colors.transparent,
    hovered: Colors.black.withValues(alpha: 0.0373),
    pressed: Colors.black.withValues(alpha: 0.0241),
  );
  _ButtonIconColorScheme _lightButtonIconColorScheme = _ButtonIconColorScheme(
    normal: Colors.black.withValues(alpha: 0.8956),
    hovered: Colors.black.withValues(alpha: 0.8956),
    pressed: Colors.black.withValues(alpha: 0.6063),
    disabled: Colors.black.withValues(alpha: 0.3614),
  );
  _ButtonBgColorScheme _darkButtonBgColorScheme = _ButtonBgColorScheme(
    normal: Colors.transparent,
    hovered: Colors.white.withValues(alpha: 0.0605),
    pressed: Colors.white.withValues(alpha: 0.0419),
  );
  _ButtonIconColorScheme _darkButtonIconColorScheme = _ButtonIconColorScheme(
    normal: Colors.white,
    hovered: Colors.white,
    pressed: Colors.white.withValues(alpha: 0.786),
    disabled: Colors.black.withValues(alpha: 0.3628),
  );

  _ButtonBgColorScheme get buttonBgColorScheme => brightness != Brightness.dark
      ? _lightButtonBgColorScheme
      : _darkButtonBgColorScheme;

  _ButtonIconColorScheme get buttonIconColorScheme =>
      brightness != Brightness.dark
          ? _lightButtonIconColorScheme
          : _darkButtonIconColorScheme;

  @override
  State<WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<WindowCaptionButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  void _onEntered({required bool hovered}) {
    setState(() => _isHovering = hovered);
  }

  void _onActive({required bool pressed}) {
    setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = widget.buttonBgColorScheme.normal;
    Color iconColor = widget.buttonIconColorScheme.normal;

    if (_isHovering) {
      bgColor = widget.buttonBgColorScheme.hovered;
      iconColor = widget.buttonIconColorScheme.hovered;
    }
    if (_isPressed) {
      bgColor = widget.buttonBgColorScheme.pressed;
      iconColor = widget.buttonIconColorScheme.pressed;
    }

    return MouseRegion(
      onExit: (value) => _onEntered(hovered: false),
      onHover: (value) => _onEntered(hovered: true),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onActive(pressed: true),
        onTapCancel: () => _onActive(pressed: false),
        onTapUp: (_) => _onActive(pressed: false),
        onTap: widget.onPressed,
        child: Container(
          constraints: const BoxConstraints(minWidth: 46, minHeight: 32),
          decoration: BoxDecoration(
            color: bgColor,
          ),
          child: Center(
            child: WindowCaptionButtonIcon(
              color: iconColor,
              createPainter: (color) {
                switch (widget.iconName) {
                  case _kIconChromeMinimize:
                    return _IconChromeMinimizePainter(color!);
                  case _kIconChromeMaximize:
                    return _IconChromeMaximizePainter(color!);
                  case _kIconChromeUnmaximize:
                    return _IconChromeUnmaximizePainter(color!);
                  case _kIconChromeClose:
                    return _IconChromeClosePainter(color!);
                  default:
                    return _IconChromeClosePainter(color!);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonBgColorScheme {
  _ButtonBgColorScheme({
    required this.normal,
    required this.hovered,
    required this.pressed,
  });
  final Color normal;
  final Color hovered;
  final Color pressed;
}

class _ButtonIconColorScheme {
  _ButtonIconColorScheme({
    required this.normal,
    required this.hovered,
    required this.pressed,
    required this.disabled,
  });
  final Color normal;
  final Color hovered;
  final Color pressed;
  final Color disabled;
}
