<?php
require_once '../../config/db_connect.php';
session_start();

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // 액션 파라미터 확인
    $action = isset($_POST['action']) ? $_POST['action'] : '';
    
    // JSON 응답 준비
    $response = ['success' => false, 'message' => ''];
    
    try {
        // GET 액션 - 주니어 정보 조회
        if ($action === 'get') {
            if (!isset($_POST['junior_id'])) {
                $response['message'] = '주니어 ID가 필요합니다.';
                echo json_encode($response);
                exit;
            }
            
            $junior_id = intval($_POST['junior_id']);
            
            // 주니어 정보 조회
            $stmt = $db->prepare("
                SELECT 
                    j.*, 
                    jr.relation,
                    jr.member_id
                FROM Junior j
                JOIN Junior_relation jr ON j.junior_id = jr.junior_id
                WHERE j.junior_id = ?
            ");
            
            $stmt->bind_param('i', $junior_id);
            $stmt->execute();
            $result = $stmt->get_result();
            
            if ($result->num_rows === 0) {
                $response['message'] = '주니어 정보를 찾을 수 없습니다.';
                echo json_encode($response);
                exit;
            }
            
            $junior = $result->fetch_assoc();
            
            $response['success'] = true;
            $response['junior'] = [
                'junior_id' => $junior['junior_id'],
                'junior_name' => $junior['junior_name'],
                'junior_school' => $junior['junior_school'],
                'junior_birthday' => $junior['junior_birthday'],
                'junior_register' => $junior['junior_register']
            ];
            $response['relation'] = $junior['relation'];
            $response['member_id'] = $junior['member_id'];
            
            echo json_encode($response);
            exit;
        }
        
        // ADD 액션 - 새 주니어 추가
        elseif ($action === 'add') {
            if (!isset($_POST['junior_name']) || !isset($_POST['member_id']) || !isset($_POST['relation'])) {
                $response['message'] = '필수 정보가 누락되었습니다.';
                echo json_encode($response);
                exit;
            }
            
            $junior_name = $_POST['junior_name'];
            $junior_school = $_POST['junior_school'] ?? '';
            $junior_birthday = !empty($_POST['junior_birthday']) ? $_POST['junior_birthday'] : null;
            $relation = $_POST['relation'];
            $member_id = intval($_POST['member_id']);
            
            $db->begin_transaction();
            
            // 새로운 주니어 회원 추가
            $stmt = $db->prepare("
                INSERT INTO Junior (
                    junior_name, 
                    junior_school, 
                    junior_birthday, 
                    junior_register
                ) VALUES (?, ?, ?, NOW())
            ");
            
            $stmt->bind_param(
                'sss', 
                $junior_name, 
                $junior_school, 
                $junior_birthday
            );
            
            $stmt->execute();
            $junior_id = $db->insert_id;
            
            // Junior_relation 테이블에 관계 추가
            $stmt = $db->prepare("
                INSERT INTO Junior_relation (
                    junior_id, 
                    member_id, 
                    relation
                ) VALUES (?, ?, ?)
            ");
            
            $stmt->bind_param(
                'iis', 
                $junior_id, 
                $member_id, 
                $relation
            );
            
            $stmt->execute();
            
            $db->commit();
            
            $response['success'] = true;
            $response['message'] = '주니어 회원이 추가되었습니다.';
            $response['junior_id'] = $junior_id;
            
            echo json_encode($response);
            exit;
        }
        
        // UPDATE 액션 - 기존 주니어 수정
        elseif ($action === 'update') {
            if (!isset($_POST['junior_id']) || !isset($_POST['junior_name']) || !isset($_POST['member_id']) || !isset($_POST['relation'])) {
                $response['message'] = '필수 정보가 누락되었습니다.';
                echo json_encode($response);
                exit;
            }
            
            $junior_id = intval($_POST['junior_id']);
            $junior_name = $_POST['junior_name'];
            $junior_school = $_POST['junior_school'] ?? '';
            $junior_birthday = !empty($_POST['junior_birthday']) ? $_POST['junior_birthday'] : null;
            $relation = $_POST['relation'];
            $member_id = intval($_POST['member_id']);
            
            $db->begin_transaction();
            
            // 기존 주니어 회원 수정
            $stmt = $db->prepare("
                UPDATE Junior SET 
                    junior_name = ?, 
                    junior_school = ?, 
                    junior_birthday = ?
                WHERE junior_id = ?
            ");
            
            $stmt->bind_param(
                'sssi', 
                $junior_name, 
                $junior_school, 
                $junior_birthday, 
                $junior_id
            );
            
            $stmt->execute();
            
            // Junior_relation 테이블 업데이트
            $stmt = $db->prepare("
                UPDATE Junior_relation SET 
                    relation = ?
                WHERE junior_id = ? AND member_id = ?
            ");
            
            $stmt->bind_param(
                'sii', 
                $relation, 
                $junior_id, 
                $member_id
            );
            
            $stmt->execute();
            
            $db->commit();
            
            $response['success'] = true;
            $response['message'] = '주니어 정보가 수정되었습니다.';
            
            echo json_encode($response);
            exit;
        }
        
        // DELETE 액션 - 주니어 삭제
        elseif ($action === 'delete') {
            if (!isset($_POST['junior_id'])) {
                $response['message'] = '주니어 ID가 필요합니다.';
                echo json_encode($response);
                exit;
            }
            
            $junior_id = intval($_POST['junior_id']);
            $member_id = isset($_POST['member_id']) ? intval($_POST['member_id']) : 0;
            
            $db->begin_transaction();
            
            // Junior_relation 테이블에서 관계 삭제
            $relation_stmt = $db->prepare("
                DELETE FROM Junior_relation 
                WHERE junior_id = ? " . 
                ($member_id > 0 ? "AND member_id = ?" : "")
            );
            
            if ($member_id > 0) {
                $relation_stmt->bind_param('ii', $junior_id, $member_id);
            } else {
                $relation_stmt->bind_param('i', $junior_id);
            }
            
            $relation_stmt->execute();
            
            // Junior 테이블에서 주니어 삭제
            $junior_stmt = $db->prepare("
                DELETE FROM Junior 
                WHERE junior_id = ?
            ");
            
            $junior_stmt->bind_param('i', $junior_id);
            $junior_stmt->execute();
            
            $db->commit();
            
            $response['success'] = true;
            $response['message'] = '주니어 정보가 삭제되었습니다.';
            
            echo json_encode($response);
            exit;
        }
        
        // 유효하지 않은 액션
        else {
            $response['message'] = '유효하지 않은 액션입니다: ' . $action;
            echo json_encode($response);
            exit;
        }
        
    } catch (Exception $e) {
        if (isset($db) && $db->connect_errno === 0) {
            $db->rollback();
        }
        $response['message'] = '오류가 발생했습니다: ' . $e->getMessage();
        echo json_encode($response);
        exit;
    }
} else {
    echo json_encode(['success' => false, 'message' => '잘못된 요청 방식입니다.']);
    exit;
} 