-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

-- Creating tables
CREATE TABLE players (
	player_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
	first_name VARCHAR(30) NOT NULL,
	last_name VARCHAR(30) NOT NULL,
	email VARCHAR(50) NOT NULL
);

CREATE TABLE characters (
	character_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    player_id INT UNSIGNED NOT NULL,
    name VARCHAR(30) NOT NULL,
    level TINYINT UNSIGNED NOT NULL,
    CONSTRAINT characters_fk_players
		FOREIGN KEY (player_id)
        REFERENCES players (player_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE winners (
	character_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    name VARCHAR(30) NOT NULL,
    CONSTRAINT winners_fk_characters
		FOREIGN KEY (character_id)
        REFERENCES characters (character_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE character_stats (
	character_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    health INT SIGNED NOT NULL,
    armor INT UNSIGNED NOT NULL,
    CONSTRAINT character_stats_fk_characters
		FOREIGN KEY (character_id)
        REFERENCES characters (character_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE teams (
	team_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    name VARCHAR(30) NOT NULL
);

CREATE TABLE team_members (
	team_member_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    team_id INT UNSIGNED NOT NULL,
    character_id INT UNSIGNED NOT NULL,
    CONSTRAINT team_members_fk_team
		FOREIGN KEY (team_id)
        REFERENCES teams (team_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
	CONSTRAINT team_members_fk_characters
		FOREIGN KEY (character_id)
        REFERENCES characters (character_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE  
);
    
CREATE TABLE items (
	item_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    name VARCHAR(30) NOT NULL,
    armor INT UNSIGNED NOT NULL,
    damage INT UNSIGNED NOT NULL
);

CREATE TABLE inventory (
	inventory_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    item_id INT UNSIGNED NOT NULL,
    CONSTRAINT inventory_fk_characters
		FOREIGN KEY (character_id)
        REFERENCES characters (character_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
	CONSTRAINT inventory_fk_items
		FOREIGN KEY (item_id)
        REFERENCES items (item_id)
		ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE equipped (
	equipped_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    item_id INT UNSIGNED NOT NULL,
    CONSTRAINT equipped_fk_characters
		FOREIGN KEY (character_id)
        REFERENCES characters (character_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
	CONSTRAINT equipped_fk_items
		FOREIGN KEY (item_id)
        REFERENCES items (item_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE OR REPLACE VIEW character_items AS
	SELECT c.character_id, c.name AS character_name, 
		it.name AS item_name, it.armor, it.damage
    FROM characters c
    INNER JOIN inventory iv
		ON c.character_id = iv.character_id
	INNER JOIN items it
		ON iv.item_id = it.item_id
    UNION
    SELECT c.character_id, c.name AS character_name, 
		it.name AS item_name, it.armor AS armor, it.damage AS damage
    FROM characters c
	INNER JOIN equipped e
		ON c.character_id = e.character_id
	INNER JOIN items it
		ON e.item_id = it.item_id
	ORDER BY character_name, item_name ASC;
    
CREATE OR REPLACE VIEW team_items AS
	SELECT t.team_id, t.name AS team_name, it.name AS item_name, it.armor, it.damage
	FROM teams t
    INNER JOIN team_members tm
		ON t.team_id = tm.team_id
	INNER JOIN inventory iv
		ON tm.character_id = iv.character_id
	INNER JOIN items it
		ON iv.item_id = it.item_id
    UNION
    SELECT t.team_id, t.name AS team_name, it.name AS item_name, it.armor, it.damage
    FROM teams t
    INNER JOIN team_members tm
		ON t.team_id = tm.team_id
    INNER JOIN equipped e
		ON tm.character_id = e.character_id
	INNER JOIN items it
		ON e.item_id = it.item_id
	ORDER BY team_name, item_name ASC;

DELIMITER ;;
CREATE FUNCTION armor_total(character_id INT)
RETURNS INT UNSIGNED
DETERMINISTIC
BEGIN
	DECLARE armor_by_id INT;
	DECLARE armor_sum INT;

    SELECT SUM(it.armor) INTO armor_by_id
		FROM items it
        INNER JOIN equipped e
			ON it.item_id = e.item_id
		WHERE character_id = e.character_id;
	SELECT cs.armor INTO armor_sum
		FROM character_stats cs
        WHERE character_id = cs.character_id;
        
	RETURN armor_sum + armor_by_id;
END;;

CREATE PROCEDURE attack(being_attacked INT, weapon_used INT)
BEGIN
    DECLARE character_armor INT UNSIGNED;
    DECLARE character_damage INT UNSIGNED;
    DECLARE character_health INT SIGNED;
    DECLARE result INT SIGNED;
    
    SELECT armor_total(being_attacked) INTO character_armor;
    SELECT it.damage INTO character_damage
		FROM equipped e
        INNER JOIN items it
			ON e.item_id = it.item_id
		WHERE e.equipped_id = weapon_used;
        
	SET result = character_damage - character_armor;
    
    SELECT cs.health INTO character_health
		FROM character_stats cs
        WHERE cs.character_id = being_attacked;
    CASE 
	WHEN result > 0 THEN
	    SET character_health = character_health - result;
	    	CASE
	        WHEN character_health <= 0 THEN
	    	    DELETE FROM characters
            	    WHERE character_id = being_attacked;
		END CASE;
            UPDATE character_stats SET health = character_health 
            WHERE character_id = being_attacked;
			
    END CASE;
END;;

CREATE PROCEDURE equip(equip_id INT UNSIGNED)
BEGIN
    DECLARE character_inventory INT UNSIGNED;
    DECLARE inventory_item INT UNSIGNED;
    
    SELECT i.character_id INTO character_inventory
	FROM  inventory i
        WHERE equip_id = i.inventory_id;
    SELECT i.item_id INTO inventory_item
	FROM inventory i
        WHERE equip_id = i.inventory_id;
    DELETE FROM inventory i
    	WHERE i.inventory_id = equip_id;
    INSERT INTO equipped
	(character_id, item_id)
    VALUES
	(character_inventory, inventory_item);
END;;

CREATE PROCEDURE unequip(remove_id INT UNSIGNED)
BEGIN
    DECLARE character_equipped INT UNSIGNED;
    DECLARE equipped_item INT UNSIGNED;
    
    SELECT e.character_id INTO character_equipped
	FROM  equipped e
        WHERE remove_id = e.equipped_id;
    SELECT e.item_id INTO equipped_item
	FROM equipped e
        WHERE remove_id = e.equipped_id;
    DELETE FROM equipped e
	WHERE equipped_id = remove_id;
    INSERT INTO inventory
	(character_id, item_id)
	VALUES
	(character_equipped, equipped_item);
END;;

CREATE PROCEDURE set_winners(winning INT UNSIGNED)
BEGIN
    DECLARE team_member_id INT UNSIGNED;
    DECLARE member_name VARCHAR(30);
    DECLARE row_not_found INT DEFAULT FALSE;
    
    DECLARE winners_cursor CURSOR FOR
	SELECT tm.character_id, c.name
	    FROM team_members tm
	    INNER JOIN characters c
	        ON tm.character_id = c.character_id
		WHERE tm.team_id = winning;
    DECLARE CONTINUE HANDLER FOR NOT FOUND
	SET row_not_found = TRUE;
        
	DELETE FROM winners;
    
    OPEN winners_cursor;
    winners_loop : LOOP
    
    FETCH winners_cursor INTO team_member_id, member_name;
    
    IF row_not_found THEN
		LEAVE winners_loop;
	END IF;
    
    INSERT INTO winners
		(character_id, name)
	VALUES
		(team_member_id, member_name);
	END LOOP winners_loop;
    CLOSE winners_cursor;		
END;;

DELIMITER ;
