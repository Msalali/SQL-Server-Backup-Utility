USE yourDB -- change DB Name
GO

IF OBJECT_ID(N'dbo.GetDatabaseSizeReport', N'P') IS NOT NULL
    DROP PROCEDURE dbo.GetDatabaseSizeReport;
GO

CREATE PROCEDURE dbo.GetDatabaseSizeReport
AS
BEGIN
    SET NOCOUNT ON;
WITH AllocationSize AS (
    SELECT 
        container_id,
        SUM(total_pages) AS total_pages
    FROM sys.allocation_units
    GROUP BY container_id
),
TableSizes AS (
    SELECT 
        t.name AS ObjectName,
        'Table' AS ObjectType,
        SUM(p.rows) AS TotalRows,
        SUM(a.total_pages) * 8.0 / 1024 AS ObjectSizeMB
    FROM sys.tables t
    INNER JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)
    INNER JOIN AllocationSize a ON p.partition_id = a.container_id
    GROUP BY t.name
),
ViewSizes AS (
    SELECT 
        v.name AS ObjectName,
        'View' AS ObjectType,
        NULL AS TotalRows,
        0.0 AS ObjectSizeMB
    FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
),
CombinedObjects AS (
    SELECT *, 1 AS SortOrder FROM TableSizes
    UNION ALL
    SELECT *, 2 AS SortOrder FROM ViewSizes
),
DatabaseSize AS (
    SELECT 
        SUM(size) * 8.0 / 1024 AS TotalDBSizeMB
    FROM sys.master_files
    WHERE DB_NAME(database_id) = DB_NAME()
),
TotalObjectSize AS (
    SELECT 
        N'--- Size Objects ---' AS ObjectName,
        'Total' AS ObjectType,
        NULL AS TotalRows,
        SUM(ObjectSizeMB) AS ObjectSizeMB,
        3 AS SortOrder
    FROM CombinedObjects
),
DBSizeRow AS (
    SELECT 
        N'--- DB All Size ---' AS ObjectName,
        'DB Total' AS ObjectType,
        NULL AS TotalRows,
        TotalDBSizeMB AS ObjectSizeMB,
        4 AS SortOrder
    FROM DatabaseSize
)
SELECT 
    DB_NAME() AS Database_Name,
    CONVERT(VARCHAR, GETDATE(), 120) AS Date_Report,
    ObjectName AS Object_Name,
    ObjectType AS Object_Type,
    ISNULL(CAST(TotalRows AS VARCHAR), N'--') AS Total_Rows,
    CAST(ObjectSizeMB AS DECIMAL(10,2)) AS [Size (MB)]
FROM (
    SELECT * FROM CombinedObjects
    UNION ALL
    SELECT * FROM TotalObjectSize
    UNION ALL
    SELECT * FROM DBSizeRow
) AS FinalResult
ORDER BY SortOrder, [Size (MB)] DESC;
  
END
GO
