#!/usr/bin/env bash
# Initialise the bind-mounted data directory with the expected subdirectories.
# Runs every time the container starts, after the host directory has been
# mounted at /workdir/data.

mkdir -p /workdir/data/visualization \
         /workdir/data/output \
         /workdir/data/csv \
         /workdir/data/figures

# Hand off to whatever the user asked to run (default: bash).
exec "$@"