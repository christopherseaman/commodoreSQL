-- Configuration settings for DuckDB
PRAGMA memory_limit='${MEM_LIMIT}';
PRAGMA threads=${NUM_THREADS};
PRAGMA temp_directory='/tmp';
PRAGMA enable_progress_bar=true;
PRAGMA force_compression='ZSTD';  -- Add compression for large tables
PRAGMA checkpoint_threshold='4GB';  -- Optimize checkpointing
PRAGMA enable_object_cache=true;  -- Cache frequently accessed objects
PRAGMA preserve_insertion_order=false;  -- Optimize for analytical queries
