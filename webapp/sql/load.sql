LOAD DATA LOCAL INFILE '/var/lib/mysql-files/5_user_presents_not_receive_data.tsv' REPLACE INTO TABLE user_presents FIELDS ESCAPED BY '|' IGNORE 1 LINES ;
