#!/bin/sh

kubectl patch svc epas16-rw -p '{"spec":{"type":"NodePort"}}'

kubectl -n edb get svc 