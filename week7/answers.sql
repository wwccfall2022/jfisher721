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
		ON t.team_id = tm.character_id
	INNER JOIN characters c
	INNER JOIN inventory iv
		ON tm.character_id = iv.character_id
	INNER JOIN items it
		ON iv.item_id = it.item_id
	UNION
    SELECT t.team_id, t.name AS team_name, it.name AS item_name, it.armor, it.damage
    FROM teams t
    INNER JOIN team_members tm
		ON t.team_id = tm.character_id
    INNER JOIN equipped e
		ON tm.character_id = e.character_id
	INNER JOIN items it
		ON e.item_id = it.item_id
	ORDER BY team_name, item_name ASC;
