import 'package:flutter/cupertino.dart';
import 'package:juta_app/widget/custom_progress_indicator%20copy.dart';
import 'package:juta_app/widget/progress_bar.dart';


class ProgressDialog {

  double? progress;

  static Future<void> show(BuildContext context, GlobalKey key) async {
    return showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Container(
            key: key,
            child: const CustomProgressIndicator(),
          );
        });
  }

  Future<void> showProcess(BuildContext context, GlobalKey key) async {
    return showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Container(key: key, child: const ProgressBar());
        });
  }

  static Future<void> unshow(BuildContext context, GlobalKey key) async {
    Navigator.pop(context);
  }

  static void hide(GlobalKey? key) {
    Navigator.of(key!.currentContext!, rootNavigator: true).pop();
  }
}
