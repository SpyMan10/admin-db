#sql::mysql=root:root@localhost:3306

-- Trello like application database :
--
-- Entities :
--   * Users
--     |--> Each user can own at most 5 boards.
--   * Authentications
--     |--> Each users have one authentication information (passwd, ...).
--     |--> When owner is removed, all his auth data should be removed too.
--   * Boards
--     |--> Each board have can own multiple columns.
--     |--> Each board is owned by a single user.
--     |--> When owner is removed, all his boards should be removed too.
--   * Columns
--     |--> Each column can own multiple cards.
--     |--> Each column is owned by a boards
--   * Members
--     |--> Each boards can have multiple members.
--     |--> When author is removed (Users), authorId must be set to null.
--   * Cards
--     |--> Each cards is owned by a boards, an have a single author (member).


-- #####################
-- ##     SCHEMAS     ##
-- #####################


-- Create database that include all non-sensitive data.
CREATE SCHEMA _App;

-- Create database that include all sensitive data (authentication data).
CREATE SCHEMA _Security;


-- #####################
-- ##  TABLE SPACES   ##
-- #####################

-- General TABLESPACE (common for all tables)
CREATE TABLESPACE _Tbs_App
  ADD DATAFILE '_Tbs_App.ibd'
  ENGINE = 'InnoDB';

-- Warning: Must be inactive before deleted
-- ALTER UNDO TABLESPACE _UndoTbs_App SET INACTIVE;
CREATE UNDO TABLESPACE _UndoTbs_App
  ADD DATAFILE '_UndoTbs_App.ibu'
  ENGINE = 'InnoDB';

-- #####################
-- ##     TABLES      ##
-- #####################


-- Create user table that contains all application users.
CREATE TABLE _App.Users
(
  id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username  VARCHAR(64) NOT NULL,
  firstname VARCHAR(64) NOT NULL,
  lastname  VARCHAR(64) NOT NULL,
  email     VARCHAR(64) NOT NULL UNIQUE,
  -- Registration date of this user.
  createdAt TIMESTAMP   NOT NULL DEFAULT current_timestamp(),
  -- By default NULL, when this row is updated, set to current_timestamp().
  updatedAt TIMESTAMP            DEFAULT NULL ON UPDATE current_timestamp()
) ENGINE = 'InnoDB'
  TABLESPACE _Tbs_App;

-- Create authentication table that contains all sensitive information (ex: authentication data).
CREATE TABLE _Security.Authentications
(
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  -- ForeignKey --> Users(id).
  userId          BIGINT UNSIGNED NOT NULL UNIQUE,
  -- User password hash.
  passwd          TEXT            NOT NULL,
  updatedAt       TIMESTAMP DEFAULT NULL ON UPDATE current_timestamp(),
  -- Last password update, default null, value if defined on INSERT new entry by trigger.
  passwdUpdatedAt TIMESTAMP DEFAULT NULL,
  -- Owner of this authentication data
  FOREIGN KEY (userId) REFERENCES _App.Users (id) ON DELETE CASCADE
) ENGINE = 'InnoDB';

-- Create table board that contains all boards created by users.
CREATE TABLE _App.Boards
(
  id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  -- User that own this board.
  ownerId   BIGINT UNSIGNED NOT NULL,
  title     VARCHAR(64)     NOT NULL,
  -- HexColor #RRGGBB
  color     VARCHAR(7)      NOT NULL DEFAULT '#ffffff',
  createdAt TIMESTAMP       NOT NULL DEFAULT current_timestamp(),
  updatedAt TIMESTAMP                DEFAULT NULL ON UPDATE current_timestamp(),

  FOREIGN KEY (ownerId) REFERENCES _App.Users (id) ON DELETE CASCADE
) ENGINE = 'InnoDB'
  TABLESPACE _Tbs_App;

-- Create table members that contains all board's members.
CREATE TABLE _App.Members
(
  id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  -- ForeignKey --> Users(id).
  userId  BIGINT UNSIGNED NULL,
  -- ForeignKey --> Boards(id).
  boardId BIGINT UNSIGNED NOT NULL,
  joinAt  TIMESTAMP       NOT NULL DEFAULT current_timestamp(),

  FOREIGN KEY (userId) REFERENCES _App.Users (id) ON DELETE SET NULL,
  FOREIGN KEY (boardId) REFERENCES _App.Boards (id) ON DELETE CASCADE
) ENGINE = 'InnoDB'
  TABLESPACE _Tbs_App;

-- Create table columns that contains all board's columns.
CREATE TABLE _App.Columns
(
  id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title     VARCHAR(32)     NOT NULL,
  -- ForeignKey --> Boards(id).
  boardId   BIGINT UNSIGNED NOT NULL,
  -- Position of this column on the board.
  pos       INT UNSIGNED    NOT NULL,
  createdAt TIMESTAMP       NOT NULL DEFAULT current_timestamp(),
  updatedAt TIMESTAMP                DEFAULT NULL ON UPDATE current_timestamp(),

  FOREIGN KEY (boardId) REFERENCES _App.Boards (id) ON DELETE CASCADE
) ENGINE = 'InnoDB'
  TABLESPACE _Tbs_App;

-- Create table cards that contains all board's cards
CREATE TABLE _App.Cards
(
  id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  -- ForeignKey --> Columns(id).
  columnId  BIGINT UNSIGNED NOT NULL,
  -- ForeignKey --> Members(id).
  authorId  BIGINT UNSIGNED NOT NULL,
  -- Position of this card in the column.
  pos       INT UNSIGNED    NOT NULL,
  title     VARCHAR(32)     NOT NULL,
  content   LONGTEXT        NULL,
  createdAt TIMESTAMP       NOT NULL DEFAULT current_timestamp(),
  updatedAt TIMESTAMP                DEFAULT NULL ON UPDATE current_timestamp(),

  FOREIGN KEY (columnId) REFERENCES _App.Columns (id) ON DELETE CASCADE,
  FOREIGN KEY (authorId) REFERENCES _App.Members (id)
) ENGINE = 'InnoDB'
  TABLESPACE _Tbs_App;


-- #####################
-- ##    TRIGGERS     ##
-- #####################


-- Trigger for updating _Security.Authentications (passwdUpdatedAt) automatically when
-- passwd change.
DELIMITER $$
CREATE TRIGGER _Security._Trg_AfterUpdate_Passwd
  BEFORE UPDATE
  ON _Security.Authentications
  FOR EACH ROW
BEGIN
  IF OLD.passwd != NEW.passwd THEN
    SET NEW.passwdUpdatedAt = current_timestamp();
  END IF;
END $$
DELIMITER ;

-- #####################
-- ##     HELPERS     ##
-- #####################

-- Allow NOT DETERMINISTIC functions to be created.
SET GLOBAL log_bin_trust_function_creators = 1;

-- Generate a default board name depending on user that will own this new board.
DELIMITER $$
CREATE FUNCTION _App.next_default_board_name(_userId BIGINT UNSIGNED)
  RETURNS VARCHAR(32)
  NOT DETERMINISTIC
BEGIN
  DECLARE id INT UNSIGNED;
  SELECT count(id) INTO id FROM _App.Boards b WHERE b.ownerId = _userId;
  RETURN concat('Board ', id + 1);
END $$
DELIMITER ;

-- Generate a default column name depending on the board that will own this column.
DELIMITER $$
CREATE FUNCTION _App.next_default_column_name(_boardId BIGINT UNSIGNED)
  RETURNS VARCHAR(32)
  NOT DETERMINISTIC
BEGIN
  DECLARE id INT UNSIGNED;
  SELECT count(id) INTO id FROM _App.Columns c WHERE c.boardId = _boardId;
  RETURN concat('Column ', id + 1);
END $$
DELIMITER ;

-- Generate a default card name depending on the column that will own this card.
DELIMITER $$
CREATE FUNCTION _App.next_default_card_name(_columnId BIGINT UNSIGNED)
  RETURNS VARCHAR(32)
  NOT DETERMINISTIC
BEGIN
  DECLARE id INT UNSIGNED;
  SELECT count(id) INTO id FROM _App.Cards c WHERE c.columnId = _columnId;
  RETURN concat('Card ', id + 1);
END $$
DELIMITER ;

-- Create new board and verify if the given has reached his quota of boards (max 5 per user),
-- if he got already 5, throw an error.
DELIMITER $$
CREATE PROCEDURE _App.create_board(
  IN _ownerId BIGINT UNSIGNED,
  IN _title VARCHAR(64),
  IN _color VARCHAR(7),
  OUT _retId BIGINT UNSIGNED
)
BEGIN
  DECLARE boardCount INT UNSIGNED;
  SELECT count(b.ownerId) INTO boardCount FROM _App.Boards b WHERE b.ownerId = _ownerId;

  IF boardCount = 5 THEN
    -- The given owner already own 5 boards, he can't own more, throw an error.
    SIGNAL SQLSTATE '02TMB' SET MESSAGE_TEXT = 'The given owner can\'t own more than 5 boards.';
  ELSE
    -- Otherwise insert it
    START TRANSACTION;
    INSERT INTO
      _App.Boards (ownerId, title, color) VALUE (_ownerId, _title, _color);
    -- last_insert_id() isn't recommended, but it's okay while being inside transaction.
    SELECT last_insert_id() INTO _retId;
    COMMIT;
  END IF;
END $$
DELIMITER ;

-- Create new user, you must use this PROCEDURE to create new user instead of INSERT directly.
DELIMITER $$
CREATE PROCEDURE _App.create_user(
  IN _username VARCHAR(64),
  IN _firstname VARCHAR(64),
  IN _lastname VARCHAR(64),
  IN _email VARCHAR(64),
  IN _passwd TEXT,
  OUT _retId BIGINT UNSIGNED
)
BEGIN
  SET @_userId := 0;

  START TRANSACTION;
  INSERT INTO
    _App.Users (username, firstname, lastname, email) VALUE (_username, _firstname, _lastname, _email);
  SELECT last_insert_id() INTO @_userId;
  COMMIT;

  INSERT INTO
    _Security.Authentications(userId, passwd) VALUE (@_userId, _passwd);
  SET _retId = @_userId;
END $$
DELIMITER ;


-- #####################
-- ##     SECURITY    ##
-- #####################


-- Create role for API user.
-- This is able to delete, call function, insert new record except for _App.Boards and update.
CREATE ROLE R_API;
GRANT SELECT, DELETE, UPDATE (firstname, lastname, username, email) ON _App.Users TO R_API;
-- Direct INSERT not allowed on _App.Boards, user must use _App.create_board(...) to create
-- new boards.
GRANT SELECT, DELETE, UPDATE (title, color, ownerId) ON _App.Boards TO R_API;
GRANT SELECT, INSERT, DELETE ON _App.Members TO R_API@'%';
GRANT SELECT, INSERT, DELETE, UPDATE (title, pos) ON _App.Columns TO R_API;
GRANT SELECT, INSERT, DELETE, UPDATE (title, content, pos) ON _App.Cards TO R_API;
GRANT EXECUTE ON PROCEDURE _App.create_board TO R_API;
GRANT EXECUTE ON PROCEDURE _App.create_user TO R_API;

-- Create role for authentication related operations
CREATE ROLE R_AUTH;
GRANT SELECT, UPDATE (passwd) ON _Security.Authentications TO R_AUTH;

-- Create role for administrator, this role has all the R_API privileges.
CREATE ROLE R_ADMIN;

-- Basic CRUD permissions.
GRANT R_API TO R_ADMIN;
GRANT R_AUTH TO R_ADMIN;

-- Application user.(mostly used to perform CRUD operations on data).
CREATE USER U_API@'%' IDENTIFIED BY 'U_API'
  PASSWORD EXPIRE INTERVAL 30 DAY
  PASSWORD REUSE INTERVAL 365 DAY
  PASSWORD HISTORY 20
  FAILED_LOGIN_ATTEMPTS 0;

-- Authentication user (the only user which can perform CRUD operations
-- on authentication related data such as password).
CREATE USER U_AUTH@'%' IDENTIFIED BY 'U_AUTH'
  PASSWORD EXPIRE INTERVAL 30 DAY
  PASSWORD REUSE INTERVAL 365 DAY
  PASSWORD HISTORY 20
  FAILED_LOGIN_ATTEMPTS 0;

GRANT R_API TO U_API@'%';
GRANT R_AUTH TO U_AUTH@'%';

-- Partial administrator user.
CREATE USER U_ADMIN@'%' IDENTIFIED BY 'U_ADMIN'
  PASSWORD EXPIRE INTERVAL 20 DAY
  PASSWORD REUSE INTERVAL 365 DAY
  PASSWORD HISTORY 20
  FAILED_LOGIN_ATTEMPTS 3;

GRANT R_ADMIN TO U_ADMIN@'%';

-- Super Administrator / DBA
CREATE USER U_SUPER_USER@'%' IDENTIFIED BY 'U_SUPER_USER'
  PASSWORD EXPIRE INTERVAL 10 DAY
  PASSWORD REUSE INTERVAL 365 DAY
  PASSWORD HISTORY 50
  FAILED_LOGIN_ATTEMPTS 3;

GRANT ALL PRIVILEGES ON *.* TO U_SUPER_USER@'%';
GRANT GRANT OPTION ON *.* TO U_SUPER_USER@'%';
