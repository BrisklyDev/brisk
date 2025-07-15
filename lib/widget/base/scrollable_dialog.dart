import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ScrollableDialog extends StatefulWidget {
  Widget content;
  double width;
  double height;
  Color backgroundColor;
  List<Widget>? buttons;
  Widget? title;
  double scrollviewHeight;
  double? scrollViewWidth;
  double borderRadius;
  MainAxisAlignment mainAxisAlignment;
  CrossAxisAlignment crossAxisAlignment;
  bool scrollButtonVisible;

  ScrollableDialog({
    super.key,
    required this.content,
    required this.width,
    required this.height,
    this.scrollViewWidth,
    required this.scrollviewHeight,
    required this.backgroundColor,
    this.borderRadius = 10,
    this.buttons = const [],
    this.title,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    required this.scrollButtonVisible,
  });

  @override
  State<ScrollableDialog> createState() => _ScrollableDialogState();
}

class _ScrollableDialogState extends State<ScrollableDialog> {
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Provider.of<ThemeProvider>(context, listen: false).activeTheme;
    final size = MediaQuery.of(context).size;
    return AlertDialog(
      backgroundColor: widget.backgroundColor,
      title: widget.title,
      contentPadding: EdgeInsets.all(0),
      actionsPadding: EdgeInsets.all(0),
      buttonPadding: EdgeInsets.all(0),
      insetPadding: EdgeInsets.all(0),
      titlePadding: EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      content: Container(
        width: widget.width,
        height: widget.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: widget.scrollviewHeight,
                width: widget.scrollViewWidth,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        mainAxisAlignment: widget.mainAxisAlignment,
                        crossAxisAlignment: widget.crossAxisAlignment,
                        children: [
                          Container(
                            child: widget.content,
                          )
                        ],
                      ),
                    ),
                    Visibility(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            splashColor: Colors.transparent,
                            hoverColor: Colors.white10,
                            borderRadius: BorderRadius.circular(50),
                            onTap: () {
                              scrollController.animateTo(
                                scrollController.position.maxScrollExtent,
                                duration: Duration(milliseconds: 150),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(4), // Reduces hover area
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                size: 22,
                                color: theme.widgetTheme.iconColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      visible: widget.scrollButtonVisible &&
                          scrollController.positions.isNotEmpty &&
                          scrollController.position.pixels !=
                              scrollController.position.maxScrollExtent,
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Container(
          color: Colors.black12,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: widget.buttons!,
            ),
          ),
        )
      ],
    );
  }
}
