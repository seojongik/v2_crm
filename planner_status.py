#!/usr/bin/env python3
"""
골프 플래너 앱 - 상태 확인

사용법:
  python planner_status.py
"""

import subprocess
import sys
from pathlib import Path

# 색상 코드
class Colors:
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def print_success(message):
    print(f"{Colors.GREEN}✓ {message}{Colors.RESET}")

def print_warning(message):
    print(f"{Colors.YELLOW}⚠ {message}{Colors.RESET}")

def print_error(message):
    print(f"{Colors.RED}✗ {message}{Colors.RESET}")

def run_command(cmd, cwd=None, check=True):
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            check=check,
            capture_output=True,
            text=True
        )
        return result.stdout.strip(), result.returncode
    except subprocess.CalledProcessError as e:
        if check:
            print_error(f"명령 실행 실패: {' '.join(cmd)}")
            print_error(f"에러: {e.stderr}")
            raise
        return e.stderr.strip(), e.returncode

def main():
    submodule_path = Path(__file__).parent / 'myxplanner_app'

    print(f"{Colors.BOLD}골프 플래너 앱 상태 확인{Colors.RESET}")
    print(f"경로: {submodule_path}")
    print()

    if not submodule_path.exists():
        print_error("myxplanner_app 폴더가 존재하지 않습니다.")
        sys.exit(1)

    # 현재 브랜치
    current_branch, _ = run_command(['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                                   cwd=submodule_path, check=False)
    print(f"현재 브랜치: {Colors.BOLD}{current_branch}{Colors.RESET}")

    # 현재 커밋
    current_commit, _ = run_command(['git', 'rev-parse', 'HEAD'], cwd=submodule_path)
    commit_msg, _ = run_command(['git', 'log', '-1', '--pretty=%B'], cwd=submodule_path)
    print(f"현재 커밋: {Colors.BOLD}{current_commit[:8]}{Colors.RESET}")
    print(f"커밋 메시지: {commit_msg}")
    print()

    # 로컬 변경사항
    status_output, _ = run_command(['git', 'status', '--porcelain'],
                                  cwd=submodule_path, check=False)
    if status_output:
        print_warning("로컬 변경사항:")
        for line in status_output.split('\n'):
            print(f"  {line}")
    else:
        print_success("로컬 변경사항 없음 (클린 상태)")
    print()

    # 원격과 비교
    run_command(['git', 'fetch', 'origin'], cwd=submodule_path, check=False)
    ahead_behind, _ = run_command(
        ['git', 'rev-list', '--left-right', '--count', f'origin/{current_branch}...HEAD'],
        cwd=submodule_path, check=False
    )

    if ahead_behind:
        behind, ahead = ahead_behind.split()
        if int(ahead) > 0:
            print_warning(f"GitHub보다 {ahead}개 커밋 앞섬 → python planner_push.py 실행")
        if int(behind) > 0:
            print_warning(f"GitHub보다 {behind}개 커밋 뒤짐 → python planner_pull.py 실행")
        if int(ahead) == 0 and int(behind) == 0:
            print_success("GitHub와 동기화됨")

if __name__ == '__main__':
    main()
