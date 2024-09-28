#!/bin/env bash

##
## Copyright Jonathan Battiato
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##

if [[ $# -lt 2 ]]
then
    echo "Usage: $0 <cluster-token> <first-master-address>" >&2
    exit 1
fi

apt install -y curl

curl -sfL https://get.k3s.io | \
  K3S_TOKEN=${1} \
  K3S_URL=https://${2}:6443 \
  sh -
