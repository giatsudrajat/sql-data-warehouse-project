/*
=============================
Create Database & Schema
=============================

Script Purpose:
    This script creates a new database named 'DataWarehouse' after checking if it already exists.
    If the database exists, it is dropped and recreated. Additionally, the script sets up three
    schemas within the database: 'bronze', 'silver', and 'gold'.

Warning:
    Running this script will drop the entire 'DataWarehouse' database if it exists. ALL data in
    the database will be permanently deleted. Procees with caution an ensure you have proper
    backups before running this script.
*/

USE master;
GO
  
-- Drop and recreate the 'DataWarehouse' database
IF EXISTS (SELECT 1 FROM sys.database WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO
  
-- Create the 'DataWarehouse' database
CREATE DATABASE DataWarehouse;
GO
  
USE DataWarehouse;
GO
  
-- Create Schemas
CREATE SCHEMA bronze;
GO
  
CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
