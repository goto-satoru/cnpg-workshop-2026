#!/bin/sh

mc alias set local http://localhost:9000 minio_admin minio_passwd_1614

mc ls local/barman --recursive --summarize
