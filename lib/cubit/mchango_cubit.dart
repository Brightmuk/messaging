import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/models/mchango_campaign.dart';
import 'package:messaging/services/mchango_service.dart';
import 'package:messaging/services/sms_service.dart';

part 'mchango_state.dart';


class MchangoCubit extends Cubit<MchangoState> {
  final String threadId;
  final MchangoService _service = MchangoService();
  final SmsService _smsService = SmsService();
  StreamSubscription? _smsSubscription;

  MchangoCubit(this.threadId) : super(MchangoInitial()) {
    load();
    _listenForNewContributions();
  }

  void _listenForNewContributions() {
    _smsSubscription = _smsService.onMessageUpdated.listen((event) {
      if (event.type == SmsEventType.messageReceived) load();
    });
  }

  Future<void> load() async {
    final isDemoMode = await UserDefaults.isDemoMode();
    try {
      final active = await _service.getActiveCampaign(threadId);
      final past = await _service.getCampaigns(threadId);
      final contributions = active != null
          ? await _service.getContributions(active.id!)
          : <Contribution>[];
        if (isClosed) return;
      emit(MchangoLoaded(
        isDemoMode: isDemoMode,
        activeCampaign: active,
        contributions: contributions,
        pastCampaigns: past.where((c) => !c.isActive).toList(),
      ));
    } catch (e) {
      emit(MchangoError('Failed to load campaign'));
    }
  }
  Future<void> simulateContribution() async {
    try {
      await _service.simulateContribution(threadId);
      await load();
    } catch (e) {
      emit(MchangoError('Failed to simulate contribution'));
    }
  }

  Future<void> startCampaign({
    required String name,
    double? targetAmount,
    int? endDate,
    required double openingBalance,
  }) async {
    try {
      emit(MchangoLoading());
      await _service.startCampaign(
        name: name,
        threadId: threadId,
        targetAmount: targetAmount,
        endDate: endDate,
        openingBalance: openingBalance,
      );
      await load();
    } catch (e) {
      emit(MchangoError(e.toString()));
    }
  }

  Future<void> stopCampaign() async {
    final state = this.state;
    if (state is! MchangoLoaded || state.activeCampaign?.id == null) return;
    try {
      await _service.stopCampaign(state.activeCampaign!.id!);
      await load();
    } catch (_) {
      emit(MchangoError('Failed to stop campaign'));
    }
  }
  Future<void> updateCampaign({
  required int campaignId,
  required String name,
  int? endDate,
  bool clearEndDate = false,
  double? targetAmount,
  bool clearTargetAmount = false,
}) async {
  try {
    await _service.updateCampaign(
      campaignId,
      name: name,
      endDate: endDate,
      clearEndDate: clearEndDate,
      targetAmount: targetAmount,
      clearTargetAmount: clearTargetAmount,
    );
    await load();
  } catch (_) {
    emit(MchangoError('Failed to update campaign'));
  }
}
  Future<bool> deleteCampaign(int campaignId) async {
  try {
    await _service.deleteCampaign(campaignId);
    await load();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> deleteContribution(int contributionId) async {
  try {
    await _service.deleteContribution(contributionId);
    await load();
  } catch (_) {
    emit(MchangoError('Failed to delete contribution'));
  }
}

  Future<void> exportPdf(bool isPremium, bool watchedAd) async {
    // Handled in UI layer — pass contributions to PDF generator
  }

  @override
  Future<void> close() {
    _smsSubscription?.cancel();
    return super.close();
  }
}