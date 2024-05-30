-- * Number of missing indexes
SELECT 
    DatabaseName = DB_NAME(database_id)
    ,[Number Indexes Missing] = count(*) 
FROM sys.dm_db_missing_index_details
GROUP BY DB_NAME(database_id)
ORDER BY 2 DESC;



-- * top costly missing indexes
SELECT  TOP 10 
        [Total Cost]  = ROUND(avg_total_user_cost * avg_user_impact * (user_seeks + user_scans),0) 
        , avg_user_impact
        , TableName = statement
        , [EqualityUsage] = equality_columns 
        , [InequalityUsage] = inequality_columns
        , [Include Cloumns] = included_columns
        , s.unique_compiles        
        ,s.last_user_seek
        ,s.user_seeks
FROM        sys.dm_db_missing_index_groups g 
INNER JOIN    sys.dm_db_missing_index_group_stats s 
       ON s.group_handle = g.index_group_handle 
INNER JOIN    sys.dm_db_missing_index_details d 
       ON d.index_handle = g.index_handle
ORDER BY [Total Cost] DESC;



-- * top 100 costly missing indexes on a specific db ID
SELECT  TOP 100
        [Total Cost]  = ROUND(avg_total_user_cost * avg_user_impact * (user_seeks + user_scans),0) 
        , avg_user_impact
        , TableName = statement
        , [EqualityUsage] = equality_columns 
        , [InequalityUsage] = inequality_columns
        , [Include Cloumns] = included_columns
        , s.unique_compiles        
        ,s.last_user_seek
        ,s.user_seeks
FROM        sys.dm_db_missing_index_groups g 
INNER JOIN    sys.dm_db_missing_index_group_stats s 
       ON s.group_handle = g.index_group_handle 
INNER JOIN    sys.dm_db_missing_index_details d 
       ON d.index_handle = g.index_handle
WHERE d.database_id = 43
ORDER BY [Total Cost] DESC;



-- * top 100 costly missing indexes on one or more db, where by name
SELECT  TOP 100
        [Total Cost]  = ROUND(avg_total_user_cost * avg_user_impact * (user_seeks + user_scans),0) 
        , avg_user_impact
        , TableName = statement
        , [EqualityUsage] = equality_columns 
        , [InequalityUsage] = inequality_columns
        , [Include Cloumns] = included_columns
        , s.unique_compiles        
        ,s.last_user_seek
        ,s.user_seeks
FROM		sys.dm_db_missing_index_groups g 
INNER JOIN	sys.dm_db_missing_index_group_stats s 
		ON s.group_handle = g.index_group_handle 
INNER JOIN	sys.dm_db_missing_index_details d 
		ON d.index_handle = g.index_handle
LEFT JOIN	sys.databases db
		ON db.database_id = d.database_id
WHERE db.name LIKE 'databasename'
ORDER BY [Total Cost] DESC;



-- * Find top server waits (CLR_AUTO_EVENT, CHECKPOINT_QUEUE, PAGEIOLATCH_SH, ...)
SELECT TOP 10
 [Wait type] = wait_type,
 [Wait time (s)] = wait_time_ms / 1000,
 [% waiting] = CONVERT(DECIMAL(12,2), wait_time_ms * 100.0 
               / SUM(wait_time_ms) OVER())
FROM sys.dm_os_wait_stats
WHERE wait_type NOT LIKE '%SLEEP%' 
ORDER BY wait_time_ms DESC;



-- * Find top queries by average time blocked
SELECT TOP 100
 [Average Time Blocked (s)] = (total_elapsed_time - total_worker_time) / (qs.execution_count * 1000000)
,[Total Time Blocked (s)] = total_elapsed_time - total_worker_time / 1000000
,[Execution count] = qs.execution_count
-- quote text into CSV friendly format
,[Individual Query] = '"' + SUBSTRING (qt.text,qs.statement_start_offset/2 + 1, 
         (CASE WHEN qs.statement_end_offset = -1 
            THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) 
          + '"'
-- quote text into CSV friendly format          
,[Parent Query] = '"' + qt.text + '"'
,DatabaseName = DB_NAME(qt.dbid)
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
ORDER BY [Average Time Blocked (s)] DESC;



-- * Find most executed queries by number of executions (repetitions)
SELECT TOP 10 [Execution count] = execution_count,
    [Individual Query] = SUBSTRING (
        qt.text,
        qs.statement_start_offset / 2 + 1,
        (
            CASE
                WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
                ELSE qs.statement_end_offset
            END - qs.statement_start_offset
        ) / 2
    ),
    [Parent Query] = qt.text,
    DatabaseName = DB_NAME(qt.dbid)
FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
ORDER BY [Execution count] DESC;



-- * Find top queries by average CPU
SELECT TOP 100 [Average CPU (s)] = total_worker_time / (qs.execution_count * 1000000),
    --Unit: sec
    [Total CPU (s)] = total_worker_time / 1000000,
    [Execution count] = qs.execution_count,
    qs.last_execution_time,    -- quote text into CSV friendly format
    [Individual Query] = '"' + SUBSTRING (
        qt.text,
        qs.statement_start_offset / 2 + 1,
        (
            CASE
                WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
                ELSE qs.statement_end_offset
            END - qs.statement_start_offset
        ) / 2
    ) + '"',    -- quote text into CSV friendly format
    [Parent Query] = '"' + qt.text + '"',
    DatabaseName = DB_NAME(qt.dbid)
FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
ORDER BY [Average CPU (s)] DESC;



-- * Find top queries by total CPU 
SELECT TOP 100 [Average CPU (s)] = total_worker_time / (qs.execution_count * 1000000),
    [Total CPU (s)] = total_worker_time / 1000000,
    [Execution count] = qs.execution_count, -- quote text into CSV friendly format
    [Individual Query] = '"' + SUBSTRING (
        qt.text,
        qs.statement_start_offset / 2 + 1,
        (
            CASE
                WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
                ELSE qs.statement_end_offset
            END - qs.statement_start_offset
        ) / 2
    ) + '"', -- quote text into CSV friendly format
    [Parent Query] = '"' + qt.text + '"',
    DatabaseName = DB_NAME(qt.dbid)
FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
ORDER BY [Total CPU (s)] DESC;



-- * list of all current traces
select * from sys.traces



