#!/bin/bash

echo "🎵 Flutter 앱 오디오 테스트 실행기"
echo "================================="

# 가상환경 체크
if [[ "$VIRTUAL_ENV" != "" ]]
then
    echo "✅ 가상환경 활성화됨: $VIRTUAL_ENV"
else
    echo "⚠️ 가상환경이 활성화되지 않음. 글로벌 설치로 진행..."
fi

# 필요한 패키지 설치
echo "📦 필요한 패키지 설치 중..."
pip install -r requirements.txt

# Chrome WebDriver 자동 설치 (webdriver-manager 사용)
echo "🌐 Chrome WebDriver 준비 중..."

# Flutter 앱이 실행 중인지 확인
echo "🔍 Flutter 앱 실행 상태 확인..."
if curl -s http://localhost:53928 > /dev/null 2>&1; then
    echo "✅ Flutter 앱이 http://localhost:53928에서 실행 중"
elif curl -s http://localhost:50423 > /dev/null 2>&1; then
    echo "✅ Flutter 앱이 http://localhost:50423에서 실행 중"
    sed -i '' 's|localhost:53928|localhost:50423|g' audio_test.py
else
    echo "❌ Flutter 앱이 실행되지 않음!"
    echo "   다음 명령어로 Flutter 앱을 먼저 실행하세요:"
    echo "   flutter run -d chrome"
    echo ""
    read -p "Flutter 앱을 실행한 후 Enter를 누르세요..."
fi

# 테스트 실행
echo "🧪 오디오 테스트 시작..."
python3 audio_test.py

echo "✅ 테스트 완료!"