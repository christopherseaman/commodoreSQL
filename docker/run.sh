#!/bin/bash

# Export the user and group IDs
export HOST_UID=$(id -u)
export HOST_GID=$(id -g)

# Run docker compose
docker compose up 
