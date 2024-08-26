#!/bin/bash

# Copyright 2019 The Vitess Authors.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This is an example script that starts vtctld.

cell=${CELL:-'test'}
grpc_port=15999
vtctld_web_port=15000

echo "Starting vtctld..."
# shellcheck disable=SC2086
vtctld \
 $TOPOLOGY_FLAGS \
 --cell $cell \
 --service_map 'grpc-vtctl,grpc-vtctld' \
 --backup_storage_implementation file \
 --file_backup_storage_root $VTDATAROOT/backups \
 --log_dir $VTDATAROOT/tmp \
 --port $vtctld_web_port \
 --grpc_port $grpc_port \
 --pid_file $VTDATAROOT/tmp/vtctld.pid \
  > $VTDATAROOT/tmp/vtctld.out 2>&1 &

for _ in {0..300}; do
 curl -I "http://${HOSTNAME}:${vtctld_web_port}/debug/status" &>/dev/null && break
 sleep 0.1
done

# check one last time
curl -I "http://${HOSTNAME}:${vtctld_web_port}/debug/status" &>/dev/null || fail "vtctld could not be started!"

echo -e "vtctld is running!"
