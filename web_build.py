#!/usr/bin/env python3
import subprocess
import sys
import os
from ftplib import FTP

def run_command(command, description):
    """Run a shell command and handle errors with real-time output"""
    print(f"\n{'='*50}")
    print(f"{description}")
    print(f"{'='*50}")

    try:
        # 실시간 출력을 위해 stdout과 stderr를 직접 출력
        result = subprocess.run(
            command,
            shell=True,
            check=True,
            text=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"\n❌ 에러 발생: {e}")
        if hasattr(e, 'stdout') and e.stdout:
            print(f"stdout: {e.stdout}")
        if hasattr(e, 'stderr') and e.stderr:
            print(f"stderr: {e.stderr}")
        return False

def upload_to_ftp(local_dir, remote_dir="/www/crm"):
    """Upload build files to FTP server"""
    print(f"\n{'='*50}")
    print("Uploading CRM to FTP server...")
    print(f"{'='*50}")

    # FTP credentials
    FTP_HOST = "golfcrm.mycafe24.com"
    FTP_USER = "golfcrm"
    FTP_PASS = "he0900874*"
    FTP_PORT = 21

    try:
        # Connect to FTP
        ftp = FTP()
        ftp.connect(FTP_HOST, FTP_PORT)
        ftp.login(FTP_USER, FTP_PASS)
        print(f"Connected to {FTP_HOST}")

        # Create CRM directory if not exists
        try:
            ftp.cwd("/www")
            try:
                ftp.mkd("crm")
            except:
                pass  # Directory already exists
            ftp.cwd("crm")
        except:
            print(f"Failed to create/access CRM directory")
            return False

        # Upload files recursively
        upload_directory(ftp, local_dir, "")

        ftp.quit()
        print("\nCRM upload completed successfully!")
        return True

    except Exception as e:
        print(f"FTP upload failed: {e}")
        return False

def upload_directory(ftp, local_dir, remote_subdir):
    """Recursively upload directory contents"""
    for item in os.listdir(local_dir):
        local_path = os.path.join(local_dir, item)
        remote_path = f"{remote_subdir}/{item}" if remote_subdir else item

        if os.path.isfile(local_path):
            # Upload file (overwrites existing)
            print(f"Uploading: {remote_path}")
            with open(local_path, 'rb') as f:
                ftp.storbinary(f'STOR {remote_path}', f)
        elif os.path.isdir(local_path):
            # Create directory if not exists
            try:
                ftp.mkd(remote_path)
            except:
                pass  # Directory already exists

            # Save current directory
            current_dir = ftp.pwd()

            # Change to subdirectory and upload
            ftp.cwd(remote_path)
            upload_directory(ftp, local_path, "")

            # Return to parent directory
            ftp.cwd(current_dir)

def upload_landing_to_ftp(local_dir, remote_dir="/www"):
    """Upload landing page files to FTP server (ROOT)"""
    print(f"\n{'='*50}")
    print("Uploading landing page to FTP server (ROOT)...")
    print(f"{'='*50}")

    # FTP credentials
    FTP_HOST = "golfcrm.mycafe24.com"
    FTP_USER = "golfcrm"
    FTP_PASS = "he0900874*"
    FTP_PORT = 21

    try:
        # Connect to FTP
        ftp = FTP()
        ftp.connect(FTP_HOST, FTP_PORT)
        ftp.login(FTP_USER, FTP_PASS)
        print(f"Connected to {FTP_HOST}")

        # Change to /www (ROOT)
        try:
            ftp.cwd("/www")
        except:
            print(f"Failed to access /www directory")
            return False

        # Upload files recursively
        upload_directory(ftp, local_dir, "")

        ftp.quit()
        print("\nLanding page upload completed successfully!")
        return True

    except Exception as e:
        print(f"FTP upload failed: {e}")
        return False

def main():
    print("Flutter Web & Landing Page Build & Deploy Script")
    print("=" * 50)

    # 스크립트 위치 기준으로 CRM 디렉토리 설정
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    print(f"\nWorking directory: {os.getcwd()}")
    print("=" * 50)

    # Clean build
    if not run_command("flutter clean", "Cleaning previous build..."):
        print("Failed to clean build")
        sys.exit(1)

    # Get dependencies
    if not run_command("flutter pub get", "Getting dependencies..."):
        print("Failed to get dependencies")
        sys.exit(1)

    # Build for web
    if not run_command("flutter build web", "Building for web..."):
        print("Failed to build for web")
        sys.exit(1)

    print("\n" + "=" * 50)
    print("CRM Build completed successfully!")
    print("Output directory: build/web/")
    print("=" * 50)

    # Upload CRM to FTP
    build_dir = "build/web"
    if not upload_to_ftp(build_dir):
        print("Failed to upload CRM to FTP")
        sys.exit(1)

    # Build Landing page
    landing_src_dir = "../landing"
    landing_build_dir = "../landing/build"

    if os.path.exists(landing_src_dir):
        # Change to landing directory to build
        original_dir = os.getcwd()
        os.chdir(landing_src_dir)

        print(f"\n{'='*50}")
        print("Building Landing Page...")
        print(f"{'='*50}")

        # Install dependencies if needed
        if not os.path.exists("node_modules"):
            if not run_command("npm install", "Installing landing page dependencies..."):
                print("Failed to install landing page dependencies")
                os.chdir(original_dir)
                sys.exit(1)

        # Build landing page with Vite
        if not run_command("npm run build", "Building landing page with Vite..."):
            print("Failed to build landing page")
            os.chdir(original_dir)
            sys.exit(1)

        os.chdir(original_dir)

        # Upload Landing page to FTP (only built files)
        if os.path.exists(landing_build_dir):
            if not upload_landing_to_ftp(landing_build_dir):
                print("Failed to upload landing page to FTP")
                sys.exit(1)
        else:
            print(f"\nError: Landing build directory not found at {landing_build_dir}")
            print("Build may have failed. Please check the error messages above.")
            sys.exit(1)
    else:
        print(f"\nWarning: Landing directory not found at {landing_src_dir}")

    print("\n" + "=" * 50)
    print("Build and deployment completed!")
    print("Landing (ROOT): https://golfcrm.mycafe24.com/")
    print("CRM: https://golfcrm.mycafe24.com/crm/")
    print("=" * 50)

if __name__ == "__main__":
    main()
