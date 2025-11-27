import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';
import 'api_service.dart';

class ChatNotificationService extends ChangeNotifier {
  static final ChatNotificationService _instance = ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  StreamSubscription? _unreadCountSubscription;
  StreamSubscription? _messageActivitySubscription;
  StreamSubscription? _latestMessageInfoSubscription;
  int _totalUnreadCount = 0;
  int _lastMessageTimestamp = 0;
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  BuildContext? _currentContext;
  
  // 최신 메시지 정보 캐시
  Map<String, dynamic>? _latestMessageInfo;

  int get totalUnreadCount => _totalUnreadCount;
  
  // BuildContext 설정 (스낵바 표시용)
  void setContext(BuildContext context) {
    _currentContext = context;
  }

  Future<void> initialize() async {
    print('🔧 [알림] ChatNotificationService 초기화 시작...');
    
    // AudioPlayer 초기화
    _audioPlayer = AudioPlayer();
    
    try {
      // 오디오 파일 미리 로드 (웹과 모바일 모두 지원)
      if (kIsWeb) {
        // 웹에서는 사용자 상호작용 후 오디오가 활성화됨
        print('🌐 웹 환경: 사용자 상호작용 후 오디오 활성화됨');
      }
      
      _isInitialized = true;
      print('🎵 AudioPlayer 초기화 성공');
    } catch (e) {
      print('❌ AudioPlayer 초기화 실패: $e');
    }

    // 지연된 구독 설정 (branchId가 설정될 때까지 기다림)
    _setupDelayedSubscriptions();
    
    print('🎯 [알림] ChatNotificationService 초기화 완료!');
  }
  
  void _setupDelayedSubscriptions() {
    // 3초 후에 구독 재시도 (로그인 완료 대기)
    Timer(Duration(seconds: 3), () {
      print('🔄 [알림] 지연된 구독 설정 시작...');
      setupSubscriptions();
    });
    
    // 브랜치 ID가 여전히 없으면 5초 후 한 번 더 시도
    Timer(Duration(seconds: 8), () {
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null) {
        print('🔄 [알림] 브랜치 ID 여전히 null - 추가 재시도...');
        setupSubscriptions();
      }
    });
  }
  
  void setupSubscriptions() {
    final branchId = ApiService.getCurrentBranchId();
    print('🔍 [알림] 구독 설정 시작 - branchId: $branchId');
    
    if (branchId == null) {
      print('⚠️ [알림] branchId가 여전히 null - 구독 설정 건너뜀');
      return;
    }
    
    // 기존 구독이 있다면 취소
    _unreadCountSubscription?.cancel();
    _messageActivitySubscription?.cancel();
    _latestMessageInfoSubscription?.cancel();
    
    // 읽지 않은 메시지 카운트 구독
    _unreadCountSubscription = ChatService.getUnreadMessageCountStream().listen((count) {
      int previousCount = _totalUnreadCount;
      _totalUnreadCount = count;
      
      print('🔍 [알림] 카운트 변화: $previousCount → $count');
      
      // 새 메시지가 도착했을 때만 알림음 재생 (조건 완화)
      if (count > previousCount) {
        print('🚨 [알림] 새 메시지 감지! 알림 처리 시작...');
        
        // 최신 메시지 정보 캐시 업데이트를 위해 잠깐 대기 후 알림음과 스낵바 함께 표시
        Timer(Duration(milliseconds: 500), () {
          _playNotificationSound();
          _showMessageNotification();
        });
      } else {
        print('📊 [알림] 카운트 증가 없음 - 알림 없음');
      }
      
      notifyListeners();
    });
    
    // 새로운 메시지 활동 감지 (관리자/회원 구분 없이)
    try {
      print('🔧 [알림] 메시지 활동 스트림 구독 시작...');
      _messageActivitySubscription = ChatService.getMessageActivityStream().listen(
        (timestamp) {
          print('🔍 [알림] 메시지 활동 감지: 이전 타임스탬프=$_lastMessageTimestamp, 현재=$timestamp');
          
          if (timestamp > _lastMessageTimestamp && _lastMessageTimestamp > 0) {
            print('🚨 [알림] 새로운 메시지 활동! 알림 처리 시작...');
            
            // 최신 메시지 정보 캐시 업데이트를 위해 잠깐 대기 후 알림음과 스낵바 함께 표시
            Timer(Duration(milliseconds: 500), () {
              _playNotificationSound();
              _showMessageNotification();
            });
          } else if (_lastMessageTimestamp == 0) {
            print('📊 [알림] 첫 번째 메시지 활동 기록 (알림 없음)');
          } else {
            print('📊 [알림] 메시지 활동 없음 또는 이전 메시지');
          }
          
          _lastMessageTimestamp = timestamp;
        },
        onError: (error) {
          print('❌ [알림] 메시지 활동 스트림 에러: $error');
        },
        onDone: () {
          print('✅ [알림] 메시지 활동 스트림 완료');
        }
      );
      print('✅ [알림] 메시지 활동 스트림 구독 완료');
    } catch (e) {
      print('❌ [알림] 메시지 활동 스트림 구독 실패: $e');
    }
    
    // 최신 메시지 정보 스트림 구독 (알림 표시용)
    try {
      print('🔧 [알림] 최신 메시지 정보 스트림 구독 시작...');
      _latestMessageInfoSubscription = ChatService.getLatestMessageInfoStream().listen(
        (messageInfo) {
          if (messageInfo != null) {
            _latestMessageInfo = messageInfo;
            print('📧 [알림] 최신 메시지 정보 캐시 업데이트: ${messageInfo['senderName']} - ${messageInfo['message']}');
          }
        },
        onError: (error) {
          print('❌ [알림] 최신 메시지 정보 스트림 에러: $error');
        },
        onDone: () {
          print('✅ [알림] 최신 메시지 정보 스트림 완료');
        }
      );
      print('✅ [알림] 최신 메시지 정보 스트림 구독 완료');
    } catch (e) {
      print('❌ [알림] 최신 메시지 정보 스트림 구독 실패: $e');
    }
    
    print('✅ [알림] 구독 설정 완료');
  }

  Future<void> _playNotificationSound() async {
    print('🔔 알림음 재생 시도... (초기화됨: $_isInitialized)');
    
    if (!_isInitialized || _audioPlayer == null) {
      print('⚠️ AudioPlayer가 초기화되지 않음');
      _playFallbackSound();
      return;
    }
    
    try {
      // 우선 시스템 알림음 사용 (mp3 파일 없이도 작동)
      _playFallbackSound();
      print('🔔 시스템 알림음 사용');
      
    } catch (e) {
      print('❌ 알림음 재생 실패: $e');
    }
  }

  void _playFallbackSound() {
    try {
      if (kIsWeb) {
        // 웹에서는 간단한 알림 방식 사용
        _playWebNotification();
      } else {
        // 모바일에서는 시스템 알림음 사용
        SystemSound.play(SystemSoundType.click);
        print('📱 모바일: 시스템 알림음 재생');
      }
    } catch (e) {
      print('❌ 알림음 실패: $e');
      print('🔊 DING DONG! 새 메시지 도착!');
    }
  }

  void _playWebNotification() {
    try {
      print('🌐 웹: 딩동 알림 시작');
      
      // JavaScript 함수를 동적으로 생성해서 실행
      bool success = _createInlineDingDongSound();
      
      if (!success) {
        // 백업: 기존 beep 소리
        try {
          final audio = html.AudioElement();
          audio.src = 'data:audio/wav;base64,UklGRjIAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQ4AAACA/ACA/ACA/ACA/A==';
          audio.volume = 0.5;
          audio.play().then((_) {
            print('🔔 백업 beep 소리 재생');
          }).catchError((e) {
            print('⚠️ 백업 소리도 실패: $e');
          });
        } catch (e) {
          print('⚠️ 백업 Audio Element 실패: $e');
        }
      }
      
      // 콘솔 알림은 항상 실행
      html.window.console.log('🔔 DING DONG! 새 메시지가 도착했습니다!');
      
    } catch (e) {
      print('❌ 웹 알림 전체 실패: $e');
    }
  }
  
  bool _createInlineDingDongSound() {
    try {
      // JavaScript 코드를 직접 실행
      js.context.callMethod('eval', ['''
        try {
          const audioContext = new (window.AudioContext || window.webkitAudioContext)();
          
          function playTone(frequency, duration, delay = 0, volume = 0.3) {
            setTimeout(() => {
              const oscillator = audioContext.createOscillator();
              const gainNode = audioContext.createGain();
              
              oscillator.connect(gainNode);
              gainNode.connect(audioContext.destination);
              
              oscillator.frequency.value = frequency;
              oscillator.type = 'sine';
              
              gainNode.gain.setValueAtTime(0, audioContext.currentTime);
              gainNode.gain.linearRampToValueAtTime(volume, audioContext.currentTime + 0.01);
              gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + duration);
              
              oscillator.start(audioContext.currentTime);
              oscillator.stop(audioContext.currentTime + duration);
            }, delay);
          }
          
          // 딩 (높은 톤)
          playTone(800, 0.4, 0, 0.4);
          
          // 동 (낮은 톤) - 0.3초 후
          playTone(600, 0.5, 300, 0.4);
          
          console.log('🔔 인라인 딩동 소리 재생!');
          
        } catch (error) {
          console.error('딩동 소리 생성 실패:', error);
        }
      ''']);
      
      print('🔔 인라인 딩동 소리 실행 성공');
      return true;
      
    } catch (e) {
      print('❌ 인라인 딩동 소리 실패: $e');
      return false;
    }
  }
  
  // 메시지 알림 스낵바 표시
  Future<void> _showMessageNotification() async {
    if (_currentContext == null) {
      print('⚠️ [알림] BuildContext가 없어서 스낵바 표시 불가');
      return;
    }
    
    try {
      // 캐시가 업데이트될 때까지 최대 1초 대기
      int waitCount = 0;
      while (_latestMessageInfo == null && waitCount < 10) {
        await Future.delayed(Duration(milliseconds: 100));
        waitCount++;
      }
      
      // 최신 메시지 정보 가져오기
      final latestMessageInfo = await _getLatestMessageInfo();
      
      if (latestMessageInfo == null) {
        print('⚠️ [알림] 최신 메시지 정보를 가져올 수 없음');
        return;
      }
      
      final memberName = latestMessageInfo['memberName'] ?? '알 수 없는 사용자';
      final messagePreview = latestMessageInfo['message'] ?? '새 메시지';
      final senderType = latestMessageInfo['senderType'] ?? 'unknown';
      
      String notificationText;
      IconData notificationIcon;
      Color backgroundColor;
      
      if (senderType == 'member') {
        notificationText = '$memberName님으로부터 1:1 메시지가 수신되었습니다!';
        notificationIcon = Icons.message_rounded;
        backgroundColor = Color(0xFF4CAF50); // 초록색
      } else {
        notificationText = '새로운 메시지가 전송되었습니다!';
        notificationIcon = Icons.send_rounded;
        backgroundColor = Color(0xFF2196F3); // 파란색
      }
      
      // 애니메이션이 있는 커스텀 스낵바 표시
      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    notificationIcon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        notificationText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (messagePreview.isNotEmpty && messagePreview.length < 50)
                        SizedBox(height: 2),
                      if (messagePreview.isNotEmpty && messagePreview.length < 50)
                        Text(
                          '"$messagePreview"',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.notifications_active,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
                ),
              ],
            ),
          ),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: 4), // 4초간 표시
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          action: SnackBarAction(
            label: '확인',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(_currentContext!).hideCurrentSnackBar();
            },
          ),
        ),
      );
      
      print('✅ [알림] 메시지 알림 스낵바 표시: $notificationText');
      
    } catch (e) {
      print('❌ [알림] 스낵바 표시 실패: $e');
    }
  }
  
  // 최신 메시지 정보 가져오기 (캐시 사용)
  Future<Map<String, dynamic>?> _getLatestMessageInfo() async {
    try {
      // 캐시된 정보가 있으면 사용
      if (_latestMessageInfo != null) {
        print('📧 [알림] 캐시된 메시지 정보 사용: ${_latestMessageInfo!['senderName']} - ${_latestMessageInfo!['message']}');
        
        String memberName = _latestMessageInfo!['senderName'] ?? '알 수 없는 사용자';
        String messageText = _latestMessageInfo!['message'] ?? '새로운 메시지';
        String senderType = _latestMessageInfo!['senderType'] ?? 'member';
        
        // 회원이 보낸 메시지인 경우 채팅방에서 실제 회원 이름 확인
        if (senderType == 'member' && _latestMessageInfo!['chatRoomId'] != null) {
          try {
            final chatRoomSnapshot = await FirebaseFirestore.instance
                .collection('chatRooms')
                .doc(_latestMessageInfo!['chatRoomId'])
                .get();
            
            if (chatRoomSnapshot.exists) {
              final chatRoomData = chatRoomSnapshot.data()!;
              memberName = chatRoomData['memberName'] ?? memberName;
              print('👤 [알림] 채팅방에서 회원 이름 확인: $memberName');
            }
          } catch (e) {
            print('⚠️ [알림] 채팅방 정보 조회 실패: $e');
          }
        }
        
        return {
          'memberName': memberName,
          'message': messageText,
          'senderType': senderType,
        };
      }
      
      // 캐시된 정보가 없으면 기본값 반환
      print('⚠️ [알림] 캐시된 메시지 정보가 없음 - 기본값 사용');
      return {
        'memberName': '고객',
        'message': '새로운 메시지',
        'senderType': 'member',
      };
      
    } catch (e) {
      print('❌ [알림] 최신 메시지 정보 가져오기 실패: $e');
      return {
        'memberName': '고객',
        'message': '새로운 메시지',
        'senderType': 'member',
      };
    }
  }

  void dispose() {
    _unreadCountSubscription?.cancel();
    _messageActivitySubscription?.cancel();
    _latestMessageInfoSubscription?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  // 수동으로 알림음 테스트
  Future<void> testNotificationSound() async {
    print('🧪 알림음 테스트 시작');
    await _playNotificationSound();
  }
  
  // 특정 딩동 소리 테스트
  void testSpecificSound(String soundType) {
    if (!kIsWeb) {
      print('📱 모바일에서는 지원되지 않음');
      return;
    }
    
    try {
      print('🧪 $soundType 소리 테스트');
      bool success = false;
      
      switch (soundType) {
        case 'doorbell':
          success = js.context.callMethod('createDoorbellSound') == true;
          break;
        case 'rich':
          success = js.context.callMethod('createRichDingDongSound') == true;
          break;
        case 'basic':
          success = js.context.callMethod('createDingDongSound') == true;
          break;
      }
      
      print(success ? '✅ $soundType 테스트 성공' : '❌ $soundType 테스트 실패');
    } catch (e) {
      print('❌ $soundType 테스트 에러: $e');
    }
  }
  
  // 새 메시지 시뮬레이션 (카운트 증가로 알림 테스트)
  void simulateNewMessage() {
    print('🎭 새 메시지 시뮬레이션 시작');
    int currentCount = _totalUnreadCount;
    
    // 카운트를 1 증가시켜서 새 메시지 도착 시뮬레이션
    _totalUnreadCount = currentCount + 1;
    
    print('🚨 새 메시지 감지! 이전: $currentCount, 현재: $_totalUnreadCount');
    _playNotificationSound();
    
    notifyListeners();
    
    // 3초 후 원복
    Timer(Duration(seconds: 3), () {
      _totalUnreadCount = currentCount;
      notifyListeners();
      print('🔄 메시지 카운트 원복: $_totalUnreadCount');
    });
  }
}