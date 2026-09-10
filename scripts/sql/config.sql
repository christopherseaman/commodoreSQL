-- DuckDB configuration settings
SET memory_limit='${MEM_LIMIT}';
SET temp_directory='./tmp';
SET threads=${NUM_THREADS};
--SET max_temp_directory_size='100GB';
SET preserve_insertion_order=false;
SET enable_progress_bar=true;
SET streaming_buffer_size='1GB'; 
