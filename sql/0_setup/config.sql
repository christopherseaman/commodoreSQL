-- Configuration settings for DuckDB
PRAGMA memory_limit='${MEM_LIMIT}';
PRAGMA threads=${NUM_THREADS};
PRAGMA temp_directory='/tmp';
PRAGMA enable_progress_bar=true;
