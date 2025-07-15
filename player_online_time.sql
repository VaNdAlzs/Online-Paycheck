CREATE TABLE IF NOT EXISTS `player_online_time` (
  `identifier` VARCHAR(50) NOT NULL PRIMARY KEY,
  `total_active_seconds` INT NOT NULL DEFAULT 0,
  `last_reset` DATE NOT NULL DEFAULT CURRENT_DATE()
);
