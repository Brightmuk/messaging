import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sim_card_info/sim_info.dart';

class AppSimCardState {
  final int? defaultCard;
  final List<SimInfo> allCards;

  AppSimCardState({required this.defaultCard, required this.allCards });
  bool canSend(){

    return true;
  }
  static Color getSimcardColor(String? carrier) {
    
    switch (carrier) {
      case "Safaricom":
        return Color(0xFF48BF84);
      case "Airtel":
        return Color(0xFFED4D6E);
      case "Telkom":
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }
}


