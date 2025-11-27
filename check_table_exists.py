#!/usr/bin/env python3
import pymysql
import sys

# 데이터베이스 연결 설정
db_config = {
    'host': '222.122.198.185',
    'user': 'autofms',
    'password': 'a131150*',
    'database': 'autofms',
    'charset': 'utf8mb4'
}

try:
    # 데이터베이스 연결
    connection = pymysql.connect(**db_config)
    cursor = connection.cursor()
    
    print("=== 데이터베이스 연결 성공 ===")
    
    # 1. v2_group 테이블 존재 여부 확인
    print("\n1. v2_group 테이블 존재 여부 확인:")
    cursor.execute("SHOW TABLES LIKE 'v2_group'")
    result = cursor.fetchall()
    if result:
        print("✅ v2_group 테이블 존재함")
    else:
        print("❌ v2_group 테이블 존재하지 않음")
    
    # 2. v2로 시작하는 모든 테이블 조회
    print("\n2. v2로 시작하는 모든 테이블:")
    cursor.execute("SHOW TABLES LIKE 'v2_%'")
    v2_tables = cursor.fetchall()
    for table in v2_tables:
        print(f"  - {table[0]}")
    
    # 3. group이 포함된 테이블 조회
    print("\n3. 'group'이 포함된 모든 테이블:")
    cursor.execute("SHOW TABLES LIKE '%group%'")
    group_tables = cursor.fetchall()
    for table in group_tables:
        print(f"  - {table[0]}")
    
    # 4. v2_group 테이블이 존재한다면 구조 확인
    cursor.execute("SHOW TABLES LIKE 'v2_group'")
    if cursor.fetchall():
        print("\n4. v2_group 테이블 구조:")
        cursor.execute("DESCRIBE v2_group")
        columns = cursor.fetchall()
        for column in columns:
            print(f"  - {column[0]} ({column[1]})")
        
        # 5. v2_group 테이블 데이터 확인
        print("\n5. v2_group 테이블 데이터 (처음 5개):")
        cursor.execute("SELECT * FROM v2_group WHERE branch_id = 'test' LIMIT 5")
        rows = cursor.fetchall()
        if rows:
            for row in rows:
                print(f"  - {row}")
        else:
            print("  - 데이터 없음")
    
except Exception as e:
    print(f"❌ 오류 발생: {e}")
    
finally:
    if 'connection' in locals():
        connection.close()
        print("\n=== 데이터베이스 연결 종료 ===")