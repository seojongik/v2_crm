-- v2_Term_member 테이블의 외래키 제약조건 수정
-- 기존 외래키 제약조건 삭제
ALTER TABLE v2_Term_member DROP FOREIGN KEY Term_member_ibfk_1_copy;

-- 새로운 외래키 제약조건 추가 (v3_members 테이블 참조)
ALTER TABLE v2_Term_member
ADD CONSTRAINT Term_member_ibfk_1_copy
FOREIGN KEY (member_id) REFERENCES v3_members(member_id); 