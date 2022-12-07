-- Create your tables, views, functions and procedures here!
CREATE SCHEMA social;
USE social;

CREATE TABLE users (
	user_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    first_name VARCHAR(30) NOT NULL,
    last_name VARCHAR(30) NOT NULL,
    email VARCHAR(45) NOT NULL,
    created_on DATETIME
);

CREATE TABLE sessions (
	session_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED,
    created_on TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_on TIMESTAMP NOT NULL DEFAULT NOW() ON UPDATE NOW(),
    CONSTRAINT sessions_fk_users
		FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE friends (
	user_friend_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED,
    friend_id INT UNSIGNED,
    CONSTRAINT friends_fk_users
		FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
	CONSTRAINT friends_fk_users2
		FOREIGN KEY (friend_id)
        REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);
CREATE TABLE posts (
	post_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED,
    created_on TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_on TIMESTAMP NOT NULL DEFAULT NOW() ON UPDATE NOW(),
    content VARCHAR(100),
    CONSTRAINT posts_fk_users
		FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE notifications(
	notification_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED,
    post_id INT UNSIGNED,
    CONSTRAINT notifications_fk_users
		FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
	CONSTRAINT notifications_fk_posts
		FOREIGN KEY (post_id)
		REFERENCES posts (post_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE OR REPLACE VIEW notification_posts AS
    SELECT n.user_id, u.first_name, u.last_name, p.post_id, p.content
        FROM posts p
        INNER JOIN notifications n
		ON p.post_id = n.post_id
	LEFT OUTER JOIN users u
		ON p.user_id = u.user_id;

DELIMITER ;; 

CREATE TRIGGER new_user
    AFTER INSERT ON users
    FOR EACH ROW
BEGIN
    DECLARE not_new_user INT UNSIGNED;
    DECLARE recent_post INT UNSIGNED;
    DECLARE row_not_found TINYINT DEFAULT FALSE;
    
    DECLARE user_cursor CURSOR FOR
	SELECT u.user_id
	    FROM users u
	WHERE u.user_id != NEW.user_id;
            
    DECLARE CONTINUE HANDLER FOR NOT FOUND
	SET row_not_found = TRUE;
    
    -- Creates the user joined posts
    SET @new_content = CONCAT(NEW.first_name, " ", NEW.last_name, " just joined!");
    
    INSERT INTO posts
	(user_id, content)
    VALUES
	(NEW.user_id, @new_content);
        
    SET recent_post = LAST_INSERT_ID();
	
    -- Creates the notification posts
    OPEN user_cursor;
    user_loop : LOOP
	
    	FETCH user_cursor INTO not_new_user;
	
	IF row_not_found THEN
		LEAVE user_loop;
	END IF;
	
	INSERT INTO notifications
	    (user_id, post_id)
	VALUES
	    (not_new_user, recent_post);
		
    END LOOP user_loop;
    CLOSE user_cursor;
END ;;

-- CREATE EVENT clear sessions
CREATE EVENT clear_sessions
    ON SCHEDULE EVERY 10 SECOND
	DO
        BEGIN
	    DELETE FROM sessions
            WHERE last_post < DATE_SUB(NOW(), INTERVAL 2 HOUR);
        END;;

-- CREATE PROCEDURE add_post(user_id, content)
CREATE PROCEDURE add_post(friend_post INT UNSIGNED, friend_content VARCHAR(70))
    BEGIN
	DECLARE friend INT UNSIGNED;
       	DECLARE recent_post INT UNSIGNED;
        DECLARE row_not_found INT DEFAULT FALSE;
        
        DECLARE post_cursor CURSOR FOR
	    SELECT friend_id FROM friends
            WHERE user_id = recent_post;
            
	DECLARE CONTINUE HANDLER FOR NOT FOUND
	    SET row_not_found = TRUE;
        
	INSERT INTO posts
	    (user_id, content)
	VALUES
	    (friend_post, friend_content);
		
        SET recent_post = LAST_INSERT_ID();
        
        OPEN post_cursor;
	post_loop : LOOP
	
	FETCH post_cursor INTO friend;
        IF row_not_found THEN
	    LEAVE post_loop;
	END IF;
        
        INSERT INTO notifications
	    (user_id, post_id)
	VALUES
	    (friend, recent_post);
            
	END LOOP post_loop;
        
        CLOSE post_cursor;
    END;;
 

DELIMITER ;
