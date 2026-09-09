/*
================================================================
Data Exploration: Database Metadata
================================================================
Script Purpose:
    This script explores database metadata to understand the available
    tables and column structures before performing further analysis
    or transformation.

Exploration Performed:
    - Retrieves all tables available in the database.
    - Retrieves column metadata for the 'fact_sales' table.
================================================================
*/

-- ============================================================
-- Explore Database Tables
-- ============================================================

-- Retrieve all available tables and their corresponding schemas and types
SELECT
    TABLE_CATALOG,
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES;


-- ============================================================
-- Explore fact_sales Table Structure
-- ============================================================

-- Inspect column names, data types, nullability, and maximum character length
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold'
AND TABLE_NAME = 'fact_sales';
