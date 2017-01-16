-- 1. prepare file
hadoop fs -mkdir hive/yahooFinance
hadoop fs -put data/yahooFinance.csv hive/yahooFinance

-- 2. beeline connection
!connect jdbc:hive2://192.168.1.33:10000/default

-- 3. create databases
CREATE DATABASE IF NOT EXISTS hive_1611jianlei;

-- select database and show tables
USE hive_1611jianlei;
SHOW TABLES;

-- 4. create yahooFinance table
DROP TABLE IF EXISTS yahooFinance;

-- Hive provides DATE and TIMESTAMP data types for date related fields
-- DATE values are represented in the form YYYY-MM-DD. Date ranges allowed
-- are 0000-01-01 to 9999-12-31
-- TIMESTAMP uses the format yyyy-mm-dd hh:mm:ss

CREATE TABLE yahooFinance (
        stockDate DATE,
        open FLOAT,
        high FLOAT,
        low FLOAT,
        close FLOAT,
        volume BIGINT,
        adjClose FLOAT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS textfile  -- TERMINATED BY ',' since it's csv file 
tblproperties ("skip.header.line.count"="1"); -- skip the header count 

-- Load data into table

------ NOTWORKING --
-- LOAD DATA LOCAL INPATH '/home/1611jianlei/data/yahooFinance.csv' OVERWRITE INTO TABLE yahooFinance;
------ NOTWORKING --

LOAD DATA INPATH '/user/1611jianlei/hive/yahooFinance/yahooFinance.csv' OVERWRITE INTO TABLE yahooFinance;

-- Check schema
DESCRIBE YahooFinance; 

-- Check how many rows are inserted
SELECT COUNT(*) FROM YahooFinance;


-- 5. Let’s create a Partitioned Table and load data into
DROP TABLE IF EXISTS PartitionedYahooFinance;

CREATE TABLE PartitionedYahooFinance(
        stockDate DATE,
        open FLOAT,
        high FLOAT,
        low FLOAT,
        close FLOAT,
        volume BIGINT,
        adjClose FLOAT
      )
COMMENT 'This is the Partitioned Yahoo Finance Data'
PARTITIONED BY(year STRING)
ROW FORMAT DELIMITED FIELDS
TERMINATED BY ',' STORED AS TEXTFILE;

-- check if there is any partition
-- warning: Table yahoofinance is not a partitioned table
SHOW PARTITIONS PartitionedYahooFinance;  

-- add all the data from table yahooFinance to PartitionedYahooFinance
INSERT OVERWRITE TABLE PartitionedYahooFinance
PARTITION (year = "Before 2003")
SELECT * FROM yahooFinance WHERE stockDate < '2003-01-01';

-- Check how many rows are inserted
SELECT COUNT(*) FROM PartitionedYahooFinance;

INSERT OVERWRITE TABLE PartitionedYahooFinance
PARTITION (year = "Betwwen 2003 and 2009")
SELECT * FROM yahooFinance WHERE stockDate > '2002-12-31' AND stockDate < '2010-01-01';

-- Check how many rows are inserted
SELECT COUNT(*) FROM PartitionedYahooFinance;

INSERT OVERWRITE TABLE PartitionedYahooFinance
PARTITION (year = "After 2009")
SELECT * FROM yahooFinance WHERE stockDate > '2009-12-31';

-- Check how many rows are inserted
SELECT COUNT(*) FROM PartitionedYahooFinance;

-- Check how many rows are in yahooFinance
SELECT COUNT(*) FROM yahooFinance;


DESCRIBE PartitionedYahooFinance;

SHOW PARTITIONS PartitionedYahooFinance; 



-- 6. Add a partition
ALTER TABLE PartitionedYahooFinance ADD IF NOT EXISTS PARTITION (year = 'After 2016');

-- check partitions
SHOW PARTITIONS PartitionedYahooFinance; 

-- Drop a partition
ALTER TABLE PartitionedYahooFinance DROP IF EXISTS PARTITION(year = 'After 2016');
-- check partitions
SHOW PARTITIONS PartitionedYahooFinance; 




-- 7. External vs Internal Table
-- The EXTERNAL keyword lets you create a table and provide a LOCATION so that Hive does not use a 
-- default location for this table. This comes in handy if you already have data generated. When 
-- dropping an EXTERNAL table, data in the table is NOT deleted from the file system.
-- when you drop a table, if it is managed table hive deletes both data and meta data,
-- if it is external table Hive only deletes metadata.

hadoop fs -mkdir /user/1611jianlei/hive/yahooFinance/external
hadoop fs -cp hive/yahooFinance/yahooFinance.csv hive/yahooFinance/external/
hadoop fs -mkdir /user/1611jianlei/hive/yahooFinance/internal
hadoop fs -cp hive/yahooFinance/yahooFinance.csv hive/yahooFinance/internal/

DROP TABLE IF EXISTS ExternalYahooFinance;

CREATE EXTERNAL TABLE IF NOT EXISTS ExternalYahooFinance(
        stockDate DATE,
        open FLOAT,
        high FLOAT,
        low FLOAT,
        close FLOAT,
        volume BIGINT,
        adjClose FLOAT
        )
COMMENT 'This is the External Yahoo Finance Table'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS textfile
location '/user/1611jianlei/hive/yahooFinance/external/';

SHOW TABLES;
-- See table type
DESCRIBE FORMATTED ExternalYahooFinance;
-- Drop the table ExternalYahooFinance
DROP TABLE IF EXISTS ExternalYahooFinance;
SHOW TABLES;

-- Check if the file is still there
hadoop fs -ls /user/1611jianlei/hive/yahooFinance/external


DROP TABLE IF EXISTS InternalYahooFinance;
CREATE TABLE IF NOT EXISTS InternalYahooFinance(
        stockDate DATE,
        open FLOAT,
        high FLOAT,
        low FLOAT,
        close FLOAT,
        volume BIGINT,
        adjClose FLOAT
        )
COMMENT 'This is the Internal Yahoo Finance Table'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS textfile
location '/user/1611jianlei/hive/yahooFinance/internal/';

-- See table type
DESCRIBE FORMATTED InternalYahooFinance;

-- This table is connected with the file in the hdfs path, the table is empty if
-- no file in the hdfs path
hadoop fs -rm /user/1611jianlei/hive/yahooFinance/internal/yahooFinance.csv
SELECT COUNT(*) FROM internalyahoofinance;

hadoop fs -cp hive/yahooFinance/yahooFinance.csv hive/yahooFinance/internal/
-- Check file is there 
hadoop fs -ls /user/1611jianlei/hive/yahooFinance/internal
SELECT COUNT(*) FROM internalyahoofinance;

-- Drop internal table
DROP TABLE IF EXISTS InternalYahooFinance;
SHOW TABLES;

-- The whole directory will be deleted 
hadoop fs -ls /user/1611jianlei/hive/yahooFinance/internal/


-- Switch a table from internal to external.
ALTER TABLE InternalYahooFinance SET TBLPROPERTIES('EXTERNAL'='TRUE');

-- Switch a table from external to internal.
ALTER TABLE InternalYahooFinance SET TBLPROPERTIES('EXTERNAL'='FALSE');


-- 1. recreate InternalYahooFinance
-- 2. copy csv file to internal hdfs folder
hadoop fs -mkdir /user/1611jianlei/hive/yahooFinance/internal
hadoop fs -cp hive/yahooFinance/yahooFinance.csv hive/yahooFinance/internal/
-- 3. Switch InternalYahooFinance from internal to external
ALTER TABLE InternalYahooFinance SET TBLPROPERTIES('EXTERNAL'='TRUE');
-- 4. Drop InternalYahooFinance
DROP TABLE InternalYahooFinance;
-- 5. Check csv file should still be in the internal hdfs folder
hadoop fs -ls /user/1611jianlei/hive/yahooFinance/internal

