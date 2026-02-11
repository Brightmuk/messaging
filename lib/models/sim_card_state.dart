import 'package:sms_advanced/sms_advanced.dart' as ss;

class AppSimCardState {
  final int? defaultCard;
  final List<ss.SimCard> allCards;

  AppSimCardState({required this.defaultCard, required this.allCards});
  bool canSend(){
    for(var c in allCards){
      if(c.state != ss.SimCardState.Ready){
        return false;
      }
    }
    return true;
  }
}


