#!/bin/bash
set -e

# Check if PostGIS is already available (e.g., if a different base image was used that includes it)
# Or if this script already ran successfully in a previous attempt on the same volume.
# This check is a bit tricky as the extension files might exist but extension not created.
# A simple check: if postgis.control exists, assume it's installed.
if [ -f "/usr/share/postgresql/16/extension/postgis.control" ]; then
    echo "PostGIS control file found, assuming PostGIS packages are installed."
else
    echo "PostGIS control file not found. Attempting to install PostGIS packages..."
    # Update package lists and install PostGIS for PostgreSQL 16
    # The package name might vary slightly based on the Debian version in the image
    # postgresql-16-postgis-3 is common for Debian-based PG16 images
    apt-get update
    apt-get install -y --no-install-recommends postgresql-16-postgis-3 postgresql-16-postgis-3-scripts
    echo "PostGIS packages installation attempt finished."
fi

# The following command will be executed by psql as part of the entrypoint sequence
# for .sql files. We don't need to run psql commands directly in this .sh script
# for creating the extension IF it's also in your 01_schema.sql with IF NOT EXISTS.
# However, it's good practice to ensure it here.
#
# This script's primary job is ensuring the OS packages are present.
# The CREATE EXTENSION in your schema.sql will then use these installed packages.
echo "PostGIS installation script completed. Extension creation will be handled by schema.sql."
