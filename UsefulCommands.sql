OPTION (USE HINT('QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_150'))


--Find tables that contains the specified column
SELECT      c.name  AS 'ColumnName'
            ,(SCHEMA_NAME(t.schema_id) + '.' + t.name) AS 'TableName'
FROM        sys.columns c
JOIN        sys.tables  t   ON c.object_id = t.object_id
WHERE       c.name LIKE '%MyName%'
ORDER BY    TableName
            ,ColumnName;


--Get Table Size and Rowcount
;with cte as (  
  SELECT  
  t.name as TableName,  
  SUM (s.used_page_count) as used_pages_count,  
  SUM (CASE  
              WHEN (i.index_id < 2) THEN (in_row_data_page_count + lob_used_page_count + row_overflow_used_page_count)  
              ELSE lob_used_page_count + row_overflow_used_page_count  
          END) as pages,
		  row_count
  FROM sys.dm_db_partition_stats  AS s   
  JOIN sys.tables AS t ON s.object_id = t.object_id  
  JOIN sys.indexes AS i ON i.[object_id] = t.[object_id] AND s.index_id = i.index_id  
  GROUP BY t.name, row_count  
  )  
  ,cte2 as(select  
      cte.TableName,   
      (cte.pages * 8.) as TableSizeInKB,   
      ((CASE WHEN cte.used_pages_count > cte.pages   
                  THEN cte.used_pages_count - cte.pages  
                  ELSE 0   
            END) * 8.) as IndexSizeInKB,
			cte.row_count
  from cte  
 )  
 select TableName,TableSizeInKB,IndexSizeInKB,  
 cast((TableSizeInKB+IndexSizeInKB) as varchar) [TableSizeIn+IndexSizeInKB],
 Row_Count [RowCount]
 from cte2  
 order by 2 desc  
