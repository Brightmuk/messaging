part of 'payment_cubit.dart';

sealed class PaymentState extends Equatable {
  const PaymentState();

  @override
  List<Object> get props => [];
}

final class PaymentInitial extends PaymentState {}
final class PaymentNotPaid extends PaymentState {}
final class PaymentSuccess extends PaymentState {}
final class PaymentProcessing extends PaymentState {}
final class PaymentFailed extends PaymentState {}