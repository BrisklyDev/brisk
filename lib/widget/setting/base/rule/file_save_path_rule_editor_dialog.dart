import 'dart:io';

import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/setting/rule/file_condition.dart';
import 'package:brisk/setting/rule/file_rule.dart';
import 'package:brisk/setting/rule/file_save_path_rule.dart';
import 'package:brisk/setting/rule/rule_value_type.dart';
import 'package:brisk/theme/application_theme.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/widget/base/error_dialog.dart';
import 'package:brisk/widget/base/outlined_text_field.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FileSavePathRuleEditorDialog extends StatefulWidget {
  const FileSavePathRuleEditorDialog({
    super.key,
  });

  @override
  _FileSavePathRuleEditorDialogState createState() =>
      _FileSavePathRuleEditorDialogState();
}

class _FileSavePathRuleEditorDialogState
    extends State<FileSavePathRuleEditorDialog> {
  final rules = [...SettingsCache.fileSavePathRules];
  late Map<FileCondition, String> fileConditionMap;
  late List<String> conditions;
  late AppLocalizations loc;
  late ApplicationTheme theme;
  List<TextEditingController> valueControllers = [];
  List<RuleValueType> selectedTypes = [];
  List<TextEditingController> savePathControllers = [];

  @override
  void dispose() {
    valueControllers.forEach((c) => c.dispose());
    savePathControllers.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    loc = AppLocalizations.of(context)!;
    fileConditionMap = buildDropMenuLocaleMap();
    for (final rule in rules) {
      valueControllers
          .add(TextEditingController(text: rule.valueWithTypeConsidered));
      selectedTypes.add(RuleValueType.fromRule(rule));
      savePathControllers.add(TextEditingController(text: rule.savePath));
    }
    conditions = fileConditionMap.values.toList();
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    loc = AppLocalizations.of(context)!;
    theme = Provider.of<ThemeProvider>(context).activeTheme;
    final size = MediaQuery.of(context).size;
    return ScrollableDialog(
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      height: 450,
      width: 600,
      scrollviewHeight: 400,
      scrollButtonVisible: size.height < 530,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              loc.settings_rules_edit,
              style: TextStyle(
                color: theme.textColor,
              ),
            ),
          ),
          Container(
            height: 1,
            width: 600,
            color: Color.fromRGBO(65, 65, 65, 1.0),
          )
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...rules
                      .asMap()
                      .entries
                      .map((e) => ruleItem(context, e.value, e.key))
                      .toList()
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Center(
            child: RoundedOutlinedButton(
              icon: Icons.add,
              iconColor:
                  theme.alertDialogTheme.primaryMiscButtonColor.iconColor,
              iconHoverColor:
                  theme.alertDialogTheme.primaryMiscButtonColor.hoverIconColor,
              textColor: theme.textColor,
              width: 580,
              onPressed: _onAddNewPressed,
              text: loc.btn_addNew,
              backgroundColor: theme.alertDialogTheme.surfaceColor,
              hoverBackgroundColor: Color.fromRGBO(53, 89, 143, 1),
            ),
          ),
        ],
      ),
      buttons: [
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.declineButtonColor,
          onPressed: () => Navigator.of(context).pop(),
          text: loc.btn_cancel,
        ),
        const SizedBox(width: 10),
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.acceptButtonColor,
          onPressed: _onSavePressed,
          text: loc.btn_save,
        ),
      ],
    );
  }

  Widget ruleItem(BuildContext context, FileRule rule, int idx) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
      child: Container(
        decoration: BoxDecoration(
          color: theme.alertDialogTheme.surfaceColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    "Rule ${idx + 1}",
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        rules.removeAt(idx);
                        valueControllers.removeAt(idx);
                        selectedTypes.removeAt(idx);
                      });
                    },
                    icon: const Icon(Icons.delete),
                    iconSize: 18,
                    color: Colors.red,
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${loc.condition}:",
                          style: TextStyle(
                            color: theme.textHintColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        DropdownButtonHideUnderline(
                          child: DropdownButton2<String>(
                            isExpanded: true,
                            items: conditions
                                .map((item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        item,
                                        style: TextStyle(
                                          color: theme.widgetTheme.dropDownColor
                                              .itemTextColor,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            value: readableCondition(rule.condition),
                            onChanged: (value) {
                              setState(() {
                                rule.condition = readableToCondition(value!);
                                if (rule.condition.hasNumberValue()) {
                                  rule.value = "0";
                                  valueControllers[idx].text = "0";
                                  selectedTypes[idx] = RuleValueType.MB;
                                } else {
                                  valueControllers[idx].text = "";
                                  selectedTypes[idx] = RuleValueType.Text;
                                }
                              });
                            },
                            buttonStyleData: ButtonStyleData(
                              height: 40,
                              decoration: dropDownDecoration,
                            ),
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 200,
                              decoration: dropDownDecoration,
                            ),
                            iconStyleData: IconStyleData(
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: theme.widgetTheme.iconColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${loc.value}:",
                          style: TextStyle(color: theme.textColor),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 40,
                          child: OutLinedTextField(
                            fillColor: theme.widgetTheme.dropDownColor
                                .dropDownBackgroundColor,
                            contentPadding: EdgeInsets.only(left: 10),
                            controller: valueControllers[idx],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${loc.type}:",
                          style: TextStyle(color: theme.textColor),
                        ),
                        const SizedBox(height: 5),
                        DropdownButtonHideUnderline(
                          child: DropdownButton2<String>(
                            isExpanded: true,
                            items: validUnit(rule)
                                .map((e) => e.name)
                                .map((item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        item,
                                        style: TextStyle(
                                          color: theme.widgetTheme.dropDownColor
                                              .itemTextColor,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            value: selectedTypes[idx].name,
                            onChanged: (value) {
                              setState(() {
                                selectedTypes[idx] = RuleValueType.values
                                    .where((element) => element.name == value)
                                    .first;
                              });
                            },
                            buttonStyleData: ButtonStyleData(
                              height: 40,
                              decoration: dropDownDecoration,
                            ),
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 200,
                              decoration: dropDownDecoration,
                            ),
                            iconStyleData: IconStyleData(
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: theme.widgetTheme.iconColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${loc.savePath}:",
                    style: TextStyle(color: theme.textColor),
                  ),
                  const SizedBox(height: 5),
                  DropdownButtonHideUnderline(
                    child: SizedBox(
                      height: 40,
                      child: OutLinedTextField(
                        contentPadding: EdgeInsets.only(left: 10),
                        fillColor: theme
                            .widgetTheme.dropDownColor.dropDownBackgroundColor,
                        controller: savePathControllers[idx],
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.folder,
                            color: theme.widgetTheme.iconColor,
                          ),
                          onPressed: () => pickSaveLocation(idx),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void pickSaveLocation(int idx) async {
    final newLocation = await FilePicker.platform.getDirectoryPath(
      initialDirectory: SettingsCache.saveDir.path,
    );
    if (newLocation == null) return;
    savePathControllers[idx].text = newLocation;
  }

  BoxDecoration get dropDownDecoration {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: theme.widgetTheme.dropDownColor.dropDownBackgroundColor,
    );
  }

  void _onSavePressed() {
    String? errorText = null;
    for (int i = 0; i < rules.length; i++) {
      var value = valueControllers[i].text;
      var savePath = savePathControllers[i].text;
      var type = selectedTypes[i];
      if (value.trim().isEmpty) {
        errorText = "Rule ${i + 1} has an empty value!";
      }
      if (value.contains(",")) {
        errorText = "Rule ${i + 1} has unsupported character:  \",\" ";
      }
      if (!Directory(savePath).existsSync()) {
        errorText = "Selected path for rule ${i + 1} doesn't exist!";
      }
      if (type.isNumber() && double.tryParse(value) == null) {
        errorText = "Rule ${i + 1} has invalid numerical value";
      }
    }
    if (errorText != null) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(
          height: 100,
          title: "Invalid Value",
          description: errorText!,
        ),
      );
      return;
    }
    for (int i = 0; i < rules.length; i++) {
      var rule = rules[i];
      var txtController = valueControllers[i];
      var selectedType = selectedTypes[i];
      var selectedPath = savePathControllers[i].text;
      String value;
      switch (selectedType) {
        case RuleValueType.KB:
          value = (double.parse(txtController.text) * 1024).toString();
          break;
        case RuleValueType.MB:
          value = (double.parse(txtController.text) * 1024 * 1024).toString();
          break;
        case RuleValueType.GB:
          value = (double.parse(txtController.text) * 1024 * 1024 * 1024)
              .toString();
          break;
        case RuleValueType.Text:
          value = txtController.text;
          break;
      }
      if (rule.condition == FileCondition.fileExtensionIs &&
          value.startsWith(".")) {
        value = value.replaceFirst(".", "");
      }
      rule.value = value;
      rule.savePath = selectedPath;
    }
    SettingsCache.fileSavePathRules = rules;
    Navigator.of(context).pop();
  }

  void _onAddNewPressed() {
    setState(() {
      rules.add(
        FileSavePathRule(
          condition: FileCondition.fileExtensionIs,
          value: "",
          savePath: "",
        ),
      );
      valueControllers.add(TextEditingController(text: ""));
      savePathControllers.add(TextEditingController(text: ""));
      selectedTypes.add(RuleValueType.Text);
    });
  }

  List<RuleValueType> validUnit(FileRule rule) {
    switch (FileCondition.values.byName(rule.condition.name)) {
      case FileCondition.downloadUrlContains:
      case FileCondition.fileNameContains:
      case FileCondition.fileExtensionIs:
        return [RuleValueType.Text];
      case FileCondition.fileSizeLessThan:
      case FileCondition.fileSizeGreaterThan:
        return [RuleValueType.KB, RuleValueType.MB, RuleValueType.GB];
    }
  }

  FileCondition readableToCondition(String condition) {
    if (condition == loc.ruleEditor_downloadUrlContains) {
      return FileCondition.downloadUrlContains;
    } else if (condition == loc.ruleEditor_fileNameContains) {
      return FileCondition.fileNameContains;
    } else if (condition == loc.ruleEditor_fileExtensionIs) {
      return FileCondition.fileExtensionIs;
    } else if (condition == loc.ruleEditor_fileSizeLessThan) {
      return FileCondition.fileSizeLessThan;
    } else if (condition == loc.ruleEditor_fileSizeGreaterThan) {
      return FileCondition.fileSizeGreaterThan;
    } else {
      throw Exception("Unknown condition");
    }
  }

  String readableCondition(FileCondition condition) {
    switch (condition) {
      case FileCondition.downloadUrlContains:
        return loc.ruleEditor_downloadUrlContains;
      case FileCondition.fileNameContains:
        return loc.ruleEditor_fileNameContains;
      case FileCondition.fileExtensionIs:
        return loc.ruleEditor_fileExtensionIs;
      case FileCondition.fileSizeLessThan:
        return loc.ruleEditor_fileSizeLessThan;
      case FileCondition.fileSizeGreaterThan:
        return loc.ruleEditor_fileSizeGreaterThan;
    }
  }

  Map<FileCondition, String> buildDropMenuLocaleMap() {
    return {
      FileCondition.downloadUrlContains: loc.ruleEditor_downloadUrlContains,
      FileCondition.fileNameContains: loc.ruleEditor_fileNameContains,
      FileCondition.fileExtensionIs: loc.ruleEditor_fileExtensionIs,
      FileCondition.fileSizeLessThan: loc.ruleEditor_fileSizeLessThan,
      FileCondition.fileSizeGreaterThan: loc.ruleEditor_fileSizeGreaterThan,
    };
  }
}
