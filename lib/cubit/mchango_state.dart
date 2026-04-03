part of 'mchango_cubit.dart';

// States
abstract class MchangoState {}
class MchangoInitial extends MchangoState {}
class MchangoLoading extends MchangoState {}
class MchangoLoaded extends MchangoState {
  final Campaign? activeCampaign;
  final List<Contribution> contributions;
  final List<Campaign> pastCampaigns;
  final bool isDemoMode;
  MchangoLoaded({this.activeCampaign, this.contributions = const [], this.pastCampaigns = const [], this.isDemoMode = false});
}
class MchangoError extends MchangoState {
  final String message;
  MchangoError(this.message);
}

