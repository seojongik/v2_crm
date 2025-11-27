#!/usr/bin/env python3
"""
골프 플래너 앱 동기화 스크립트

사용법:
  python sync_planner.py pull                    # GitHub에서 최신 코드 가져오기
  python sync_planner.py push                    # 로컬 변경사항 GitHub에 업로드
  python sync_planner.py push -m "커밋 메시지"  # 커밋 메시지 지정
  python sync_planner.py status                  # 현재 상태 확인
"""

import subprocess
import sys
import argparse
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
    """단계 출력"""
    print(f"{Colors.BLUE}{Colors.BOLD}▶ {message}{Colors.RESET}")

def print_success(message):
    """성공 메시지 출력"""
    print(f"{Colors.GREEN}✓ {message}{Colors.RESET}")

def print_warning(message):
    """경고 메시지 출력"""
    print(f"{Colors.YELLOW}⚠ {message}{Colors.RESET}")

def print_error(message):
    """에러 메시지 출력"""
    print(f"{Colors.RED}✗ {message}{Colors.RESET}")

def run_command(cmd, cwd=None, check=True):
    """커맨드 실행"""
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

def check_git_installed():
    """Git 설치 확인"""
    try:
        run_command(['git', '--version'])
        return True
    except:
        return False

def get_submodule_path():
    """서브모듈 경로 반환"""
    project_root = Path(__file__).parent
    return project_root / 'myxplanner_app'

def check_status():
    """현재 상태 확인"""
    submodule_path = get_submodule_path()

    print(f"{Colors.BOLD}골프 플래너 앱 상태 확인{Colors.RESET}")
    print(f"경로: {submodule_path}")
    print()

    if not submodule_path.exists():
        print_error("서브모듈이 존재하지 않습니다.")
        return False

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
            print_warning(f"GitHub보다 {ahead}개 커밋 앞섬 → push 필요")
        if int(behind) > 0:
            print_warning(f"GitHub보다 {behind}개 커밋 뒤짐 → pull 필요")
        if int(ahead) == 0 and int(behind) == 0:
            print_success("GitHub와 동기화됨")

    return True

def pull_changes():
    """GitHub에서 최신 코드 가져오기"""
    submodule_path = get_submodule_path()

    print(f"{Colors.BOLD}GitHub에서 최신 코드 가져오기{Colors.RESET}")
    print()

    if not submodule_path.exists():
        print_error("서브모듈이 존재하지 않습니다.")
        return False

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
            return False

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
    return True

def push_changes(commit_message=None):
    """로컬 변경사항 GitHub에 업로드"""
    submodule_path = get_submodule_path()

    print(f"{Colors.BOLD}로컬 변경사항 GitHub에 업로드{Colors.RESET}")
    print()

    if not submodule_path.exists():
        print_error("서브모듈이 존재하지 않습니다.")
        return False

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
                    return True

        print("할 일이 없습니다.")
        return False

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
    if not commit_message:
        print(f"{Colors.YELLOW}커밋 메시지를 입력하세요 (빈 줄로 종료):{Colors.RESET}")
        lines = []
        while True:
            line = input()
            if not line:
                break
            lines.append(line)
        commit_message = '\n'.join(lines)

    if not commit_message:
        print_error("커밋 메시지가 비어있습니다.")
        return False

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
        return False

    run_command(['git', 'push', 'origin', current_branch], cwd=submodule_path)
    print_success("Push 완료!")
    print()

    return True

def main():
    parser = argparse.ArgumentParser(
        description='골프 플래너 앱 동기화',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
사용 예시:
  python sync_planner.py pull                    # 최신 코드 가져오기
  python sync_planner.py push                    # 변경사항 업로드
  python sync_planner.py push -m "기능 추가"    # 커밋 메시지 지정
  python sync_planner.py status                  # 상태 확인
        """
    )

    parser.add_argument(
        'action',
        choices=['pull', 'push', 'status'],
        help='수행할 작업'
    )

    parser.add_argument(
        '-m', '--message',
        type=str,
        help='커밋 메시지 (push 시 사용)'
    )

    args = parser.parse_args()

    # Git 설치 확인
    if not check_git_installed():
        print_error("Git이 설치되어 있지 않습니다.")
        sys.exit(1)

    try:
        if args.action == 'status':
            success = check_status()
        elif args.action == 'pull':
            success = pull_changes()
        elif args.action == 'push':
            success = push_changes(args.message)
        else:
            print_error(f"알 수 없는 작업: {args.action}")
            sys.exit(1)

        sys.exit(0 if success else 1)

    except Exception as e:
        print_error(f"오류 발생: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
