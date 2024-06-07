CREATE EVENT SESSION [ExecWarningAndUserError] ON SERVER 
ADD EVENT sqlserver.error_reported(
    ACTION(package0.collect_system_time,sqlserver.client_app_name,sqlserver.client_connection_id,sqlserver.client_hostname,sqlserver.client_pid,sqlserver.database_name,sqlserver.session_id,sqlserver.session_server_principal_name,sqlserver.sql_text,sqlserver.username)
    WHERE (NOT [sqlserver].[like_i_sql_unicode_string]([message],N'Changed language setting%') AND NOT [sqlserver].[like_i_sql_unicode_string]([message],N'Changed database context%'))),
ADD EVENT sqlserver.execution_warning(
    ACTION(package0.collect_system_time,sqlserver.client_app_name,sqlserver.client_connection_id,sqlserver.client_hostname,sqlserver.client_pid,sqlserver.database_name,sqlserver.session_id,sqlserver.session_server_principal_name,sqlserver.sql_text,sqlserver.username))
ADD TARGET package0.event_file(SET filename=N'd:\logs\ExecWarningAndUserError.xel',max_file_size=(100),max_rollover_files=(10))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO
