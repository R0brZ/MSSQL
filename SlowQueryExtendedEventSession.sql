CREATE EVENT SESSION [SlowQueryExtendedEventSession] ON SERVER
ADD EVENT sqlserver.attention(
        ACTION(
            package0.process_id,
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_id,
            sqlserver.database_name,
            sqlserver.server_instance_name,
            sqlserver.session_id,
            sqlserver.sql_text,
            sqlserver.username
        )
        WHERE ([sqlserver].[is_system] =(0))
    ),
    ADD EVENT sqlserver.excessive_memory_spilled_to_workfiles(
        ACTION(
            package0.process_id,
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_id,
            sqlserver.database_name,
            sqlserver.server_instance_name
        )
        WHERE ([sqlserver].[is_system] =(0))
    ),
    ADD EVENT sqlserver.exchange_spill(
        ACTION(
            package0.process_id,
            sqlserver.server_instance_name,
            sqlserver.session_id,
            sqlserver.sql_text,
            sqlserver.username
        )
        WHERE ([sqlserver].[is_system] =(0))
    ),
    ADD EVENT sqlserver.hash_spill_details(
        ACTION(
            package0.process_id,
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_id,
            sqlserver.database_name,
            sqlserver.num_response_rows,
            sqlserver.server_instance_name,
            sqlserver.session_id,
            sqlserver.sql_text,
            sqlserver.username
        )
        WHERE ([sqlserver].[is_system] =(0))
    ),
    ADD EVENT sqlserver.module_end(
        SET collect_statement =(1) ACTION(
                package0.process_id,
                sqlserver.client_app_name,
                sqlserver.client_hostname,
                sqlserver.database_id,
                sqlserver.database_name,
                sqlserver.num_response_rows,
                sqlserver.server_instance_name,
                sqlserver.session_id,
                sqlserver.sql_text,
                sqlserver.username
            )
        WHERE (
                [duration] >(5000000)
                AND [database_id] >(4)
                AND NOT [sql_text] like 'WAITFOR (RECEIVE message_body FROM WMIEventProviderNotificationQueue)%'
            )
    ),
    ADD EVENT sqlserver.query_post_execution_plan_profile(
        SET collect_database_name =(1) ACTION(
                package0.process_id,
                sqlserver.client_app_name,
                sqlserver.client_hostname,
                sqlserver.database_id,
                sqlserver.database_name,
                sqlserver.server_instance_name,
                sqlserver.session_id,
                sqlserver.sql_text,
                sqlserver.username
            )
        WHERE (
                [sqlserver].[is_system] =(0)
                AND [duration] >=(5000000)
            )
    ),
    ADD EVENT sqlserver.rpc_completed(
        SET collect_statement =(1) ACTION(
                package0.process_id,
                sqlserver.client_app_name,
                sqlserver.client_hostname,
                sqlserver.database_id,
                sqlserver.database_name,
                sqlserver.num_response_rows,
                sqlserver.server_instance_name,
                sqlserver.session_id,
                sqlserver.sql_text,
                sqlserver.username
            )
        WHERE (
                [duration] >(5000000)
                AND [sqlserver].[is_system] =(0)
                AND NOT [sql_text] like 'WAITFOR (RECEIVE message_body FROM WMIEventProviderNotificationQueue)%'
            )
    ),
    ADD EVENT sqlserver.sp_statement_completed(
        SET collect_object_name =(1) ACTION(
                package0.process_id,
                sqlserver.client_app_name,
                sqlserver.client_hostname,
                sqlserver.database_id,
                sqlserver.database_name,
                sqlserver.server_instance_name,
                sqlserver.session_id,
                sqlserver.sql_text,
                sqlserver.username
            )
        WHERE (
                [duration] >(5000000)
                AND [sqlserver].[is_system] =(0)
                AND NOT [sql_text] like 'WAITFOR (RECEIVE message_body FROM WMIEventProviderNotificationQueue)%'
            )
    ),
    ADD EVENT sqlserver.sql_batch_completed(
        ACTION(
            package0.process_id,
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_id,
            sqlserver.database_name,
            sqlserver.server_instance_name,
            sqlserver.session_id,
            sqlserver.sql_text,
            sqlserver.username
        )
        WHERE (
                [duration] >(5000000)
                AND [sqlserver].[is_system] =(0)
                AND NOT [sql_text] like 'WAITFOR (RECEIVE message_body FROM WMIEventProviderNotificationQueue)%'
            )
    ),
    ADD EVENT sqlserver.sql_statement_completed(
        ACTION(
            package0.process_id,
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_id,
            sqlserver.database_name,
            sqlserver.server_instance_name,
            sqlserver.session_id,
            sqlserver.sql_text,
            sqlserver.username
        )
        WHERE (
                [duration] >(5000000)
                AND [sqlserver].[is_system] =(0)
                AND NOT [sql_text] like 'WAITFOR (RECEIVE message_body FROM WMIEventProviderNotificationQueue)%'
            )
    )
ADD TARGET package0.event_file(
        SET filename = N'd:\logs\SlowQueryLogCompact.xel',
            max_file_size =(100),
            max_rollover_files =(50)
    ) WITH (
        MAX_MEMORY = 262144 KB,
        EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
        MAX_DISPATCH_LATENCY = 10 SECONDS,
        MAX_EVENT_SIZE = 0 KB,
        MEMORY_PARTITION_MODE = NONE,
        TRACK_CAUSALITY = ON,
        STARTUP_STATE = ON
    )
GO
