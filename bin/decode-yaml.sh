#!/bin/bash

yq '.data |= with_entries(.value |= @base64d)'
