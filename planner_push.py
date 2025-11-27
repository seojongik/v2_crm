#!/usr/bin/env python3
"""
골프 플래너 앱 - 로컬 변경사항 GitHub에 업로드

사용법:
  python planner_push.py                  # 대화형 (커밋 메시지 입력)
  python planner_push.py "커밋 메시지"   # 커밋 메시지 직접 지정
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

    print(f"{Colors.BOLD}로컬 변경사항 GitHub에 업로드{Colors.RESET}")
    print(f"경로: {submodule_path}")
    print()

    if not submodule_path.exists():
        print_error("myxplanner_app 폴더가 존재하지 않습니다.")
        sys.exit(1)

    # 1. 변경사항 확인
    print_step("변경사항 확인")
    status_output, _ = run_command(['git', 'status', '--porcelain'],
                                  cwd=submodule_path, check=False)

    if not status_output:
        print_warning("변경사항이 없습니다.")

        # 커밋은 있지만 push 안된 것 확인
        current_branch, _ = run_command(['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                                       cwd=submodule_path)
        ahead_behind, _ = run_command(
            ['git', 'rev-list', '--left-right', '--count', f'origin/{current_branch}...HEAD'],
            cwd=submodule_path, check=False
        )

        if ahead_behind:
            behind, ahead = ahead_behind.split()
            if int(ahead) > 0:
                print_warning(f"Push되지 않은 커밋이 {ahead}개 있습니다.")
                response = input(f"{Colors.YELLOW}Push하시겠습니까? (y/N): {Colors.RESET}").lower()
                if response == 'y':
                    print_step(f"Push 중 (origin/{current_branch})")
                    run_command(['git', 'push', 'origin', current_branch], cwd=submodule_path)
                    print_success("Push 완료!")
                    sys.exit(0)

        print("할 일이 없습니다.")
        sys.exit(0)

    print_success("변경사항 발견:")
    print(status_output)
    print()

    # 2. 변경된 파일 목록 보기
    print_step("변경된 파일 목록")
    diff_output, _ = run_command(['git', 'diff', '--stat'], cwd=submodule_path, check=False)
    if diff_output:
        print(diff_output)
    print()

    # 3. 커밋 메시지 입력
    commit_message = None
    if len(sys.argv) > 1:
        commit_message = sys.argv[1]
    else:
        print(f"{Colors.YELLOW}커밋 메시지를 입력하세요:{Colors.RESET}")
        commit_message = input("> ")

    if not commit_message:
        print_error("커밋 메시지가 비어있습니다.")
        sys.exit(1)

    # 4. Add all
    print_step("변경사항 스테이징")
    run_command(['git', 'add', '.'], cwd=submodule_path)
    print_success("스테이징 완료")
    print()

    # 5. Commit
    print_step("커밋 생성")
    run_command(['git', 'commit', '-m', commit_message], cwd=submodule_path)
    print_success(f"커밋 완료: {commit_message}")
    print()

    # 6. Push
    current_branch, _ = run_command(['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                                   cwd=submodule_path)
    print_step(f"Push 중 (origin/{current_branch})")

    response = input(f"{Colors.YELLOW}GitHub에 Push하시겠습니까? (y/N): {Colors.RESET}").lower()
    if response != 'y':
        print_warning("Push를 취소했습니다. 커밋은 로컬에 저장되었습니다.")
        sys.exit(0)

    run_command(['git', 'push', 'origin', current_branch], cwd=submodule_path)
    print_success("Push 완료!")

if __name__ == '__main__':
    main()
