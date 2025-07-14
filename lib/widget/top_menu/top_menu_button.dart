import 'package:flutter/material.dart';

class TopMenuButton extends StatefulWidget {
  final String title;
  final Widget icon;
  final Color onHoverColor;
  final VoidCallback? onTap;
  final double fontSize;
  final Color textColor;

  const TopMenuButton({
    super.key,
    required this.title,
    required this.icon,
    this.onHoverColor = Colors.blueGrey,
    required this.onTap,
    this.fontSize = 13,
    this.textColor = Colors.white60,
  });

  @override
  State<TopMenuButton> createState() => _TopMenuButtonState();
}

class _TopMenuButtonState extends State<TopMenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: _isHovered ? widget.onHoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  top: _isHovered ? 0 : 18,
                  child: widget.icon,
                ),
                // Text appears below icon
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isHovered ? 1.0 : 0.0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 200),
                    offset: _isHovered ? Offset.zero : const Offset(0, 0.3),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: 100,
                          child: Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: widget.fontSize,
                              color: widget.textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
