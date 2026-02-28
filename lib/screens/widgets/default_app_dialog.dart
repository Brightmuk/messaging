import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/permissions_cubit.dart';
import 'package:messaging/services/default_app_reminder.dart';

void showDefaultAppPrompt(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Complete the Setup"),
      content: const Text(
        "M-Ficha works best when set as your default messaging app. ",
      ),
      actions: [
        TextButton(
          onPressed: () {
            DefaultAppReminder.markPrompted();
            Navigator.pop(context);
          },
          child: const Text("NOT NOW", style: TextStyle(color: Colors.grey)),
        ),
        FilledButton(
          onPressed: () async{
             DefaultAppReminder.markPrompted();
             await context.read<PermissionsCubit>().requestDefaultRole();
            Navigator.pop(context);
           
          },
          child: const Text("SET AS DEFAULT"),
        ),
      ],
    ),
  );
}