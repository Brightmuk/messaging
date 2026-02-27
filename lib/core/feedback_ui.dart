import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class FeedbackUi{
  final BuildContext context;
  BuildContext? _dialogContext; 
  bool _isDialogVisible = false;

  FeedbackUi(this.context);


  void showLoader(String text) {
    if (_isDialogVisible) return;

    _isDialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        _dialogContext = dialogCtx; 
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text("$text..."),
            ],
          ),
        );
      },
    );
  }

  void hideLoader() {
    if (_isDialogVisible && _dialogContext != null) {
      Navigator.of(_dialogContext!).pop();
      _dialogContext = null;
      _isDialogVisible = false;
    }
  }
  void showSuccess(String message){
    _showToast(ToastificationType.success, message);
  }
  void showError(String message){
    _showToast(ToastificationType.error, message);
  }
  void showInfo(String message){
    _showToast(ToastificationType.info, message);
  }
  void showSnackbar(String message, {bool persistent = false}){
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: theme.colorScheme.surfaceContainer,
        padding: EdgeInsets.zero,
        content: SizedBox(
          height: 20,
          child: Center(child: Text(message,style: theme.textTheme.bodySmall,)),
        ))
    );

  }
  String messageText(ToastificationType type){
    switch(type){
      case ToastificationType.error:
      return 'Error';
      case ToastificationType.success:
      return 'Success';
      case ToastificationType.info:
      return 'Please note';
      default:
        return '';
    }
  }
  void _showToast(ToastificationType type, String message){
    final theme = Theme.of(context);
    bool isDark = theme.brightness == Brightness.dark;

    toastification.show(
      backgroundColor:  isDark? theme.colorScheme.primary: null,
      foregroundColor: theme.textTheme.bodyLarge!.color,
      borderSide: isDark? BorderSide(color: theme.scaffoldBackgroundColor):null,
	  context: context,
	  type: type,
	  style: ToastificationStyle.flat,
	  title: Text(messageText(type)),
	  description: Text(message),
	  alignment: Alignment.bottomCenter,
	  autoCloseDuration: const Duration(seconds: 5),
	  borderRadius: BorderRadius.circular(12.0),
	  boxShadow: lowModeShadow,
	);
  }
}