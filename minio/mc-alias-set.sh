#!/bin/sh

mc alias set local http://localhost:9000 minio_admin minio_admin_0227

mc ls local/barman --recursive --summarize
