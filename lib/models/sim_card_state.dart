

import 'package:sim_card_info/sim_info.dart';

class AppSimCardState {
  final int? defaultCard;
  final List<SimInfo> allCards;

  AppSimCardState({required this.defaultCard, required this.allCards });
  bool canSend(){

    return true;
  }
}


