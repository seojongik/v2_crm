#!/usr/bin/env python3
"""
랜딩 페이지 - GitHub에 업로드
crm/ 폴더의 변경사항만 처리
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

def print_error(message):
    print(f"{Colors.RED}✗ {message}{Colors.RESET}")

def run_command(cmd, cwd=None, check=True):
    try:
        result = subprocess.run(
            cmd, cwd=cwd, check=check,
            capture_output=True, text=True
        )
        return result.stdout.strip(), result.returncode
    except subprocess.CalledProcessError as e:
        if check:
            print_error(f"명령 실행 실패: {' '.join(cmd)}")
            print_error(f"에러: {e.stderr}")
            raise
        return e.stderr.strip(), e.returncode

def main():
    project_root = Path(__file__).parent.parent
    
    print(f"{Colors.BOLD}랜딩 페이지 - GitHub에 업로드{Colors.RESET}")
    print(f"대상 폴더: crm/")
    print()
    
    # 1. crm/ 폴더의 변경사항만 확인
    print_step("랜딩 페이지 변경사항 확인")
    status_output, _ = run_command(
        ['git', 'status', '--porcelain', 'crm/'],
        cwd=project_root, check=False
    )
    
    if not status_output:
        print_error("crm/ 폴더에 변경사항이 없습니다.")
        sys.exit(0)
    
    print_success("변경사항 발견:")
    print(status_output)
    print()
    
    # 2. 커밋 메시지
    commit_message = None
    if len(sys.argv) > 1:
        commit_message = sys.argv[1]
    else:
        print(f"{Colors.YELLOW}커밋 메시지를 입력하세요:{Colors.RESET}")
        commit_message = input("> ")
    
    if not commit_message:
        print_error("커밋 메시지가 비어있습니다.")
        sys.exit(1)
    
    # 3. crm/ 폴더만 스테이징
    print_step("랜딩 페이지 스테이징")
    run_command(['git', 'add', 'crm/'], cwd=project_root)
    print_success("스테이징 완료 (crm/ 폴더만)")
    print()
    
    # 4. 커밋
    print_step("커밋 생성")
    run_command(
        ['git', 'commit', '-m', f"[CRM] {commit_message}"],
        cwd=project_root
    )
    print_success(f"커밋 완료: [CRM] {commit_message}")
    print()
    
    # 5. Push 확인
    current_branch, _ = run_command(
        ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
        cwd=project_root
    )
    
    response = input(f"{Colors.YELLOW}GitHub에 Push하시겠습니까? (y/N): {Colors.RESET}").lower()
    if response != 'y':
        print_error("Push를 취소했습니다.")
        sys.exit(0)
    
    # 6. Push
    print_step(f"Push 중 (origin/{current_branch})")
    run_command(['git', 'push', 'origin', current_branch], cwd=project_root)
    print_success("Push 완료!")

if __name__ == '__main__':
    main()

