-- ============================================
-- DATABASE
-- ============================================
DROP DATABASE IF EXISTS household_ledger;

CREATE DATABASE household_ledger;

USE household_ledger;

-- ============================================
-- 1. 회원 테이블
-- ============================================
CREATE TABLE users (
    user_no INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(20) NOT NULL UNIQUE,
    user_pw VARCHAR(100) NOT NULL,
    user_nm VARCHAR(30) NOT NULL,
    status_cd CHAR(1) DEFAULT 'Y' CHECK (status_cd IN ('Y', 'N')),
    reg_dt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2. 공통 코드 테이블
-- ============================================
CREATE TABLE comm_code (
    comm_cd CHAR(5) PRIMARY KEY,
    grp_cd CHAR(3) NOT NULL,
    comm_nm VARCHAR(30) NOT NULL,
    sort_no TINYINT DEFAULT 1
);

-- ============================================
-- 3. 가계부 테이블
-- ============================================
CREATE TABLE ledgers (
    ledger_no INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_no INT UNSIGNED NOT NULL,
    comm_cd CHAR(5) NOT NULL,
    amount INT NOT NULL,
    trans_dt DATE NOT NULL,
    memo VARCHAR(255),
    status_cd CHAR(1) DEFAULT 'Y' CHECK (status_cd IN ('Y', 'N')),
    FOREIGN KEY (user_no) REFERENCES users (user_no),
    FOREIGN KEY (comm_cd) REFERENCES comm_code (comm_cd)
);

-- ============================================
-- 4. 월별 예산 테이블
-- ============================================
CREATE TABLE budgets (
    budget_no INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_no INT UNSIGNED NOT NULL,
    target_year INT NOT NULL,
    target_month INT NOT NULL,
    budget_amt INT NOT NULL,
    reg_dt DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_budget_user_month UNIQUE (
        user_no,
        target_year,
        target_month
    ),
    CONSTRAINT fk_budget_user FOREIGN KEY (user_no) REFERENCES users (user_no) ON DELETE CASCADE
);

-- ============================================
-- 5. 카테고리별 예산 테이블 (확장용)
-- ============================================
CREATE TABLE budget_cates (
    budget_cate_no INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    budget_no INT UNSIGNED NOT NULL,
    comm_cd CHAR(5) NOT NULL,
    budget_amt INT NOT NULL,
    reg_dt DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_budget_cate UNIQUE (budget_no, comm_cd),
    CONSTRAINT fk_budget_cate_budget FOREIGN KEY (budget_no) REFERENCES budgets (budget_no) ON DELETE CASCADE,
    CONSTRAINT fk_budget_cate_comm FOREIGN KEY (comm_cd) REFERENCES comm_code (comm_cd)
);

-- ============================================
-- 6. 월별 요약 테이블 (통계용)
-- ============================================
CREATE TABLE monthly_summary (
    summary_no INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_no INT UNSIGNED NOT NULL,
    target_year INT NOT NULL,
    target_month INT NOT NULL,
    total_inc_amt INT DEFAULT 0,
    total_exp_amt INT DEFAULT 0,
    CONSTRAINT uk_summary_user_month UNIQUE (
        user_no,
        target_year,
        target_month
    ),
    FOREIGN KEY (user_no) REFERENCES users (user_no)
);

-- ============================================
-- [함수] 공통 코드명 조회
-- ============================================
DELIMITER $$

CREATE FUNCTION fn_get_comm_nm (_comm_cd CHAR(5))
RETURNS VARCHAR(30)
DETERMINISTIC
BEGIN
    DECLARE _comm_nm VARCHAR(30);

    SELECT comm_nm
      INTO _comm_nm
      FROM comm_code
     WHERE comm_cd = _comm_cd;

    RETURN IFNULL(_comm_nm, '');
END$$

DELIMITER;

-- ============================================
-- [트리거] 가계부 INSERT → 월별 요약 반영
-- ============================================
DELIMITER $$

CREATE TRIGGER trg_ledger_after_insert
AFTER INSERT ON ledgers
FOR EACH ROW
BEGIN
    IF NEW.comm_cd LIKE 'EXP%' THEN
        INSERT INTO monthly_summary (user_no, target_year, target_month, total_exp_amt)
        VALUES (NEW.user_no, YEAR(NEW.trans_dt), MONTH(NEW.trans_dt), NEW.amount)
        ON DUPLICATE KEY UPDATE
            total_exp_amt = total_exp_amt + NEW.amount;
    ELSE
        INSERT INTO monthly_summary (user_no, target_year, target_month, total_inc_amt)
        VALUES (NEW.user_no, YEAR(NEW.trans_dt), MONTH(NEW.trans_dt), NEW.amount)
        ON DUPLICATE KEY UPDATE
            total_inc_amt = total_inc_amt + NEW.amount;
    END IF;
END$$

DELIMITER;

-- ============================================
-- [트리거] 가계부 DELETE → 월별 요약 차감
-- ============================================
DELIMITER $$

CREATE TRIGGER trg_ledger_after_delete
AFTER DELETE ON ledgers
FOR EACH ROW
BEGIN
    IF OLD.comm_cd LIKE 'EXP%' THEN
        UPDATE monthly_summary
           SET total_exp_amt = total_exp_amt - OLD.amount
         WHERE user_no = OLD.user_no
           AND target_year = YEAR(OLD.trans_dt)
           AND target_month = MONTH(OLD.trans_dt);
    ELSE
        UPDATE monthly_summary
           SET total_inc_amt = total_inc_amt - OLD.amount
         WHERE user_no = OLD.user_no
           AND target_year = YEAR(OLD.trans_dt)
           AND target_month = MONTH(OLD.trans_dt);
    END IF;
END$$

DELIMITER;

-- ============================================
-- 기초 데이터
-- ============================================
INSERT INTO comm_code VALUES ('INC01', 'INC', '월급', 1);

INSERT INTO comm_code VALUES ('EXP01', 'EXP', '식비', 1);

INSERT INTO comm_code VALUES ('EXP02', 'EXP', '교통비', 2);

INSERT INTO
    users (user_id, user_pw, user_nm)
VALUES ('test', '1234', '정진호');