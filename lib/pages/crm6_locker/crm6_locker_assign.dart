import 'package:flutter/material.dart';
import 'locker_api_service.dart';
import 'crm6_locker_model.dart';

class LockerAssignService {
  static void showAssignmentPopup(
    BuildContext context,
    Map<String, dynamic> locker,
    Crm6LockerModel model,
    void Function(VoidCallback) setState,
  ) {
    setState(() {
      model.selectedLockerId = locker['locker_id'];
      model.selectedLockerInfo = locker;
      model.showAssignmentPopup = true;
      model.isUnpaidPaymentMode = false; // 일반 배정 모드
      model.clearAssignmentForm();
      
      // 기본값 설정
      model.startDateController?.text = DateTime.now().toString().split(' ')[0];
      model.selectedDiscountIncludeOption = '제외'; // 디폴트로 제외 선택
      model.discountMinController?.text = '300';
      model.discountRatioController?.text = '50';
      
      // 기존 데이터가 있으면 폼에 채우기
      if (locker['member_id'] != null) {
        model.selectedPaymentMethod = locker['payment_method'];
        model.discountMinController?.text = locker['locker_discount_condition_min']?.toString() ?? '';
        model.discountRatioController?.text = locker['locker_discount_ratio']?.toString() ?? '';
        
        // 할인 조건 설정
        final discountCondition = locker['locker_discount_condition'];
        if (discountCondition == '기간권 이용포함') {
          model.selectedDiscountIncludeOption = '포함';
        } else if (discountCondition == '기간권 이용제외') {
          model.selectedDiscountIncludeOption = '제외';
        }
        
        model.startDateController?.text = locker['locker_start_date'] ?? '';
        model.endDateController?.text = locker['locker_end_date'] ?? '';
        model.remarkController?.text = locker['locker_remark'] ?? '';
      }
    });
  }

  static Future<void> saveAssignment(
    BuildContext context,
    Crm6LockerModel model,
    VoidCallback refreshData,
    void Function(VoidCallback) setState,
  ) async {
    if (model.selectedLockerId == null) return;

    // 필수 필드 검증 (비고 제외)
    if (model.selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원을 선택해주세요.')),
      );
      return;
    }
    
    if (model.selectedPaymentMethod == null || model.selectedPaymentMethod!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('납부방법을 선택해주세요.')),
      );
      return;
    }
    
    if (model.selectedPayMethod == null || model.selectedPayMethod!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('결제방법을 선택해주세요.')),
      );
      return;
    }
    
    
    if (model.startDateController?.text.isEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시작일을 입력해주세요.')),
      );
      return;
    }
    
    if (model.endDateController?.text.isEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('종료일을 입력해주세요.')),
      );
      return;
    }
    
    if (model.totalPriceController?.text.isEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('총 금액을 입력해주세요.')),
      );
      return;
    }

    try {
      // 할인 조건 문자열 생성
      String? discountCondition;
      if (model.selectedDiscountIncludeOption != null) {
        discountCondition = model.selectedDiscountIncludeOption == '포함' ? '기간권 이용포함' : '기간권 이용제외';
      }

      final data = {
        'payment_frequency': model.selectedPaymentMethod ?? '', // 일시납부/정기결제(월별)
        'payment_method': model.selectedPayMethod ?? '', // 현금결제/크레딧 결제/카드결제
        'member_id': model.selectedMember?['member_id'],
        'locker_discount_condition_min': int.tryParse(model.discountMinController?.text ?? '') ?? 0,
        'locker_discount_ratio': double.tryParse(model.discountRatioController?.text ?? '') ?? 0,
        'locker_discount_condition': discountCondition,
        'locker_start_date': model.startDateController?.text ?? '',
        'locker_end_date': model.endDateController?.text ?? '',
        'locker_remark': model.remarkController?.text ?? '',
      };

      // 락커 상태 업데이트
      await LockerApiService.updateLocker(
        lockerId: model.selectedLockerId!,
        data: data,
      );

      // 계약 이력 추가 (회원이 선택된 경우에만)
      if (model.selectedMember != null) {
        final totalPrice = int.tryParse(model.totalPriceController?.text ?? '0') ?? 0;
        final lockerName = model.selectedLockerInfo?['locker_name'] ?? '';
        
        int? billId;
        
        // 크레딧 결제인 경우 v2_bills 테이블 먼저 업데이트
        if (model.selectedPayMethod == '크레딧 결제') {
          // 먼저 크레딧 잔액 확인
          final creditInfo = await LockerApiService.getMemberCreditInfo(model.selectedMember!['member_id']);
          
          if (!creditInfo['hasCreditContract']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(creditInfo['message'])),
            );
            return;
          }
          
          if (creditInfo['totalBalance'] < totalPrice) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('크레딧 잔액이 부족합니다. 현재 잔액: ${creditInfo['totalBalance']}원, 필요 금액: ${totalPrice}원')),
            );
            return;
          }
          
          billId = await LockerApiService.processCreditPayment(
            memberId: model.selectedMember!['member_id'],
            memberName: model.selectedMember!['member_name'] ?? '',
            lockerName: lockerName,
            lockerStart: model.startDateController?.text ?? '',
            lockerEnd: model.endDateController?.text ?? '',
            paymentFrequency: model.selectedPaymentMethod ?? '',
            totalPrice: totalPrice,
          );
        }
        
        // 락커 청구서 추가 (v2_Locker_bills)
        await LockerApiService.addLockerBill(
          lockerId: model.selectedLockerId!,
          memberId: model.selectedMember!['member_id'],
          lockerName: lockerName,
          lockerStart: model.startDateController?.text ?? '',
          lockerEnd: model.endDateController?.text ?? '',
          paymentFrequency: model.selectedPaymentMethod ?? '',
          paymentMethod: model.selectedPayMethod ?? '',  // 결제수단 추가
          totalPrice: totalPrice,
          discountRatio: double.tryParse(model.discountRatioController?.text ?? '0') ?? 0,
          remark: model.remarkController?.text ?? '',
          billId: billId,
          billType: model.isUnpaidPaymentMode ? '미납결제' : '신규배정', // 미납 결제 모드일 때 구분
        );
        
        // 계약 이력 추가 (현금결제/카드결제인 경우에만)
        if (model.selectedPayMethod != '크레딧 결제') {
          await LockerApiService.addLockerContractHistory(
            memberId: model.selectedMember!['member_id'],
            memberName: model.selectedMember!['member_name'] ?? '',
            lockerName: lockerName,
            lockerStart: model.startDateController?.text ?? '',
            lockerEnd: model.endDateController?.text ?? '',
            payMethod: model.selectedPayMethod ?? '',
            paymentFrequency: model.selectedPaymentMethod ?? '',
            totalPrice: totalPrice,
            billId: billId,
          );
        }
      }

      setState(() {
        model.showAssignmentPopup = false;
      });
      refreshData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('락커 배정이 완료되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('락커 배정 실패: $e')),
      );
    }
  }

  static void showReturnPopup(
    BuildContext context,
    Map<String, dynamic> locker,
    Crm6LockerModel model,
    void Function(VoidCallback) setState,
  ) async {
    setState(() {
      model.selectedLockerId = locker['locker_id'];
      model.selectedLockerInfo = locker;
      model.showReturnPopup = true;
      model.clearReturnForm();
    });

    // 결제 정보 조회
    if (locker['member_id'] != null) {
      try {
        final paymentInfo = await LockerApiService.getLockerPaymentInfo(
          memberId: locker['member_id'],
          lockerName: locker['locker_name'] ?? '',
          returnDate: model.returnDateController?.text ?? DateTime.now().toString().split(' ')[0],
        );
        
        setState(() {
          model.returnPaymentInfo = paymentInfo;
          if (paymentInfo['success'] == true) {
            model.availableRefundMethods = List<String>.from(paymentInfo['available_refund_methods']);
          } else {
            model.availableRefundMethods = ['현금', '환불불가']; // 기본 옵션
          }
        });
      } catch (e) {
        print('결제 정보 조회 실패: $e');
        setState(() {
          model.availableRefundMethods = ['현금', '환불불가']; // 기본 옵션
        });
      }
    }
  }

  static Future<void> processReturn(
    BuildContext context,
    Crm6LockerModel model,
    VoidCallback refreshData,
    void Function(VoidCallback) setState,
  ) async {
    if (model.selectedLockerId == null || model.selectedRefundMethod == null) return;

    // 반납일자 확인
    if (model.returnDateController?.text.isEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('반납일자를 입력해주세요.')),
      );
      return;
    }

    // 환불불가가 아닌 경우 환불금액 확인
    if (model.selectedRefundMethod != '환불불가') {
      final refundAmount = double.tryParse(model.refundAmountController?.text ?? '');
      if (refundAmount == null || refundAmount < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('유효한 환불금액을 입력해주세요.')),
        );
        return;
      }
    }

    try {
      // 락커 반납 처리 (회원 정보 초기화)
      final data = {
        'member_id': null,
        'payment_frequency': null,          // 납부방법 초기화 추가
        'payment_method': null,
        'locker_discount_condition_min': null,
        'locker_discount_ratio': null,
        'locker_start_date': null,
        'locker_end_date': null,
        'locker_remark': null,
      };

      // 락커 상태 업데이트
      await LockerApiService.updateLocker(
        lockerId: model.selectedLockerId!,
        data: data,
      );

      // 락커 청구서 반납 업데이트 (환불 정보 등록)
      if (model.selectedLockerInfo?['member_id'] != null) {
        final lockerName = model.selectedLockerInfo?['locker_name'] ?? '';
        final refundAmount = model.selectedRefundMethod == '환불불가' 
            ? 0.0 
            : double.tryParse(model.refundAmountController?.text ?? '') ?? 0.0;
            
        print('🔍 [DEBUG] 락커 청구서 반납 처리 시작');
        
        // 크레딧환불인 경우 v2_bills에 환불 레코드 추가
        if (model.selectedRefundMethod == '크레딧환불' && refundAmount > 0) {
          // 결제 정보에서 bill_id 가져오기
          final billId = model.returnPaymentInfo?['bill']?['bill_id'];
          
          if (billId != null) {
            print('🔍 [DEBUG] 크레딧 환불 처리 시작 - bill_id: $billId');
            final creditRefundResult = await LockerApiService.processCreditRefund(
              billId: billId,
              lockerName: lockerName,
              refundAmount: refundAmount,
              returnDate: model.returnDateController?.text ?? '',
            );
            
            print('🔍 [DEBUG] 크레딧 환불 처리 결과: $creditRefundResult');
            
            if (creditRefundResult['success'] == false) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('크레딧 환불 실패: ${creditRefundResult['message']}')),
              );
              return;
            }
          }
        }
        
        final billUpdateResult = await LockerApiService.updateLockerBillForReturn(
          memberId: model.selectedLockerInfo!['member_id'],
          lockerName: lockerName,
          returnDate: model.returnDateController?.text ?? '', // 사용자가 입력한 반납일자
          refundType: model.selectedRefundMethod ?? '',
          refundAmount: refundAmount,
        );
        
        print('🔍 [DEBUG] 락커 청구서 반납 처리 결과: $billUpdateResult');
        
        if (billUpdateResult['success'] == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('청구서 업데이트 실패: ${billUpdateResult['message']}')),
          );
          return; // 청구서 업데이트 실패 시 중단
        }
      }

      setState(() {
        model.showReturnPopup = false;
      });
      refreshData();

      String message = '락커 반납이 완료되었습니다.';
      if (model.selectedRefundMethod != '환불불가') {
        final refundAmount = double.tryParse(model.refundAmountController?.text ?? '') ?? 0;
        message += '\n환불금액: ${refundAmount.toInt()}원 (${model.selectedRefundMethod})';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('락커 반납 실패: $e')),
      );
    }
  }
}