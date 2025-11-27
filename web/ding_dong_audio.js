// Flutter 앱용 딩동 알림음 생성기
window.createDingDongSound = function() {
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
                
                // 부드러운 페이드 인/아웃
                gainNode.gain.setValueAtTime(0, audioContext.currentTime);
                gainNode.gain.linearRampToValueAtTime(volume, audioContext.currentTime + 0.01);
                gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + duration);
                
                oscillator.start(audioContext.currentTime);
                oscillator.stop(audioContext.currentTime + duration);
            }, delay);
        }
        
        // 딩 (높은 톤)
        playTone(800, 0.3, 0, 0.4);
        
        // 동 (낮은 톤) - 0.3초 후
        playTone(600, 0.4, 300, 0.4);
        
        console.log('🔔 딩동 소리 재생 완료!');
        return true;
        
    } catch (error) {
        console.error('딩동 소리 생성 실패:', error);
        return false;
    }
};

// 더 리치한 딩동 소리 (화음 포함)
window.createRichDingDongSound = function() {
    try {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        
        function playChord(frequencies, duration, delay = 0, volume = 0.2) {
            setTimeout(() => {
                frequencies.forEach(freq => {
                    const oscillator = audioContext.createOscillator();
                    const gainNode = audioContext.createGain();
                    
                    oscillator.connect(gainNode);
                    gainNode.connect(audioContext.destination);
                    
                    oscillator.frequency.value = freq;
                    oscillator.type = 'sine';
                    
                    gainNode.gain.setValueAtTime(0, audioContext.currentTime);
                    gainNode.gain.linearRampToValueAtTime(volume, audioContext.currentTime + 0.02);
                    gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + duration);
                    
                    oscillator.start(audioContext.currentTime);
                    oscillator.stop(audioContext.currentTime + duration);
                });
            }, delay);
        }
        
        // 딩 (C 메이저 코드 - 높은 음역)
        playChord([523, 659, 784], 0.4, 0, 0.25);
        
        // 동 (F 메이저 코드 - 낮은 음역) - 0.35초 후
        playChord([349, 440, 523], 0.5, 350, 0.25);
        
        console.log('🎵 리치 딩동 소리 재생 완료!');
        return true;
        
    } catch (error) {
        console.error('리치 딩동 소리 생성 실패:', error);
        return false;
    }
};

// 도어벨 스타일 딩동
window.createDoorbellSound = function() {
    try {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        
        function createBell(frequency, duration, delay = 0) {
            setTimeout(() => {
                // 메인 톤
                const osc1 = audioContext.createOscillator();
                const gain1 = audioContext.createGain();
                
                // 하모닉스 (배음)
                const osc2 = audioContext.createOscillator();
                const gain2 = audioContext.createGain();
                
                osc1.connect(gain1);
                osc2.connect(gain2);
                gain1.connect(audioContext.destination);
                gain2.connect(audioContext.destination);
                
                osc1.frequency.value = frequency;
                osc1.type = 'sine';
                
                osc2.frequency.value = frequency * 2; // 옥타브 위
                osc2.type = 'sine';
                
                // 벨 울림 효과
                gain1.gain.setValueAtTime(0, audioContext.currentTime);
                gain1.gain.linearRampToValueAtTime(0.3, audioContext.currentTime + 0.01);
                gain1.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + duration);
                
                gain2.gain.setValueAtTime(0, audioContext.currentTime);
                gain2.gain.linearRampToValueAtTime(0.1, audioContext.currentTime + 0.01);
                gain2.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + duration);
                
                osc1.start(audioContext.currentTime);
                osc1.stop(audioContext.currentTime + duration);
                osc2.start(audioContext.currentTime);
                osc2.stop(audioContext.currentTime + duration);
            }, delay);
        }
        
        // 딩 (E5)
        createBell(659, 0.4, 0);
        
        // 동 (C5) - 0.3초 후
        createBell(523, 0.5, 300);
        
        console.log('🚪 도어벨 딩동 소리 재생 완료!');
        return true;
        
    } catch (error) {
        console.error('도어벨 소리 생성 실패:', error);
        return false;
    }
};

console.log('🎵 딩동 오디오 라이브러리 로드 완료');
console.log('사용법: window.createDingDongSound(), window.createRichDingDongSound(), window.createDoorbellSound()');