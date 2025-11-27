#!/usr/bin/env python3
"""
골프 플래너 앱 - GitHub에서 최신 코드 가져오기

사용법:
  python planner_pull.py
"""

import subprocess
import sys
from pathlib import Path
from datetime import datetime

# 색상 코드
class Colors:
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def print_step(message):
    print(f"{Colors.BLUE}{Colors.BOLD}▶ {message}{Colors.RESET}")

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

    print(f"{Colors.BOLD}GitHub에서 최신 코드 가져오기{Colors.RESET}")
    print(f"경로: {submodule_path}")
    print()

    if not submodule_path.exists():
        print_error("myxplanner_app 폴더가 존재하지 않습니다.")
        sys.exit(1)

    # 1. 로컬 변경사항 확인
    print_step("로컬 변경사항 확인")
    status_output, _ = run_command(['git', 'status', '--porcelain'],
                                  cwd=submodule_path, check=False)
    if status_output:
        print_warning("로컬에 커밋되지 않은 변경사항이 있습니다:")
        print(status_output)
        print()
        response = input(f"{Colors.YELLOW}변경사항을 stash하고 계속하시겠습니까? (y/N): {Colors.RESET}").lower()
        if response != 'y':
            print("Pull을 취소했습니다.")
            sys.exit(0)

        # stash
        print_step("로컬 변경사항 임시 저장 (stash)")
        run_command(['git', 'stash', 'save', f'Auto stash before pull - {datetime.now()}'],
                   cwd=submodule_path)
        print_success("변경사항을 stash에 저장했습니다")
        print()
    else:
        print_success("로컬 변경사항 없음")
        print()

    # 2. 현재 브랜치 확인
    current_branch, _ = run_command(['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                                   cwd=submodule_path)
    print(f"현재 브랜치: {Colors.BOLD}{current_branch}{Colors.RESET}")
    print()

    # 3. Fetch
    print_step("원격 저장소 정보 가져오기")
    run_command(['git', 'fetch', 'origin'], cwd=submodule_path)
    print_success("Fetch 완료")
    print()

    # 4. Pull
    print_step(f"최신 코드 병합 (origin/{current_branch})")
    output, _ = run_command(['git', 'pull', 'origin', current_branch], cwd=submodule_path)
    if "Already up to date" in output:
        print_success("이미 최신 상태입니다")
    else:
        print_success("Pull 완료")
        print(output)
    print()

    # 5. Stash 복원 여부 확인
    stash_list, _ = run_command(['git', 'stash', 'list'], cwd=submodule_path, check=False)
    if stash_list and 'Auto stash before pull' in stash_list:
        print()
        response = input(f"{Colors.YELLOW}임시 저장한 변경사항을 복원하시겠습니까? (y/N): {Colors.RESET}").lower()
        if response == 'y':
            print_step("Stash 복원")
            run_command(['git', 'stash', 'pop'], cwd=submodule_path, check=False)
            print_success("변경사항을 복원했습니다")

    print()
    print_success("Pull 완료!")

if __name__ == '__main__':
    main()
