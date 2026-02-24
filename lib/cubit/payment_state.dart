part of 'payment_cubit.dart';

sealed class PaymentState extends Equatable {
  const PaymentState();

  @override
  List<Object> get props => [];
}

final class PaymentInitial extends PaymentState {}
final class PaymentPaid extends PaymentState {}
final class PaymentNotPaid extends PaymentState {}
final class PaymentSuccess extends PaymentState {
  final bool isRestored;

  const PaymentSuccess({required this.isRestored});
}
final class PaymentProcessing extends PaymentState {}
final class PaymentFailed extends PaymentState {
  final String message;

  const PaymentFailed({required this.message});
}