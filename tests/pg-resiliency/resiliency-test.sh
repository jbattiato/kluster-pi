#!/bin/bash

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

set -m

if [[ "${TRACE:-}" == "true" ]]
then
    set -x
fi

usage(){
    echo "Usage: $0 <cluster_name> <service_lb_db>" >&2
    echo "" >&2
    exit 1
}

exec_sql(){
    psql -h "${SERVICE_IP}" -U app -c "${1}" >/dev/null 2>&1
}

create_table(){
    echo ""
    echo "Table creation..."
    echo ""
    exec_sql "DROP TABLE IF EXISTS uptime"
    exec_sql "CREATE TABLE uptime (id serial, time timestamp, note varchar)"
}

start_writing_table(){
    echo "Starting writing..."
    echo ""
    exec_sql "INSERT INTO uptime(time,note) VALUES(NOW(),'iteration begin')"
    
    while true
    do
        exec_sql "INSERT INTO uptime(time) VALUES(NOW())"
    done &
    
    PID=$(jobs -p)
}

kill_script(){
    kill -15 "${PID/#/-}" $$
}

force_delete_primary(){
    echo "Deleting ${PRIMARY} pod..."
    echo ""
    kubectl delete pod "${PRIMARY}" --now >/dev/null 2>&1
}

cordon_node(){
    echo "Draining ${NODE} node..."
    echo ""
    kubectl cordon "${NODE}" >/dev/null 2>&1
}

uncordon_node(){
    echo "Uncordon ${NODE} node..."
    echo ""
    kubectl uncordon "${NODE}"
}

wait_for_primary(){
    echo "Waiting for primary to be healthy again..."
    echo ""

    until exec_sql "SELECT 1"
    do
        sleep 1
    done

    sleep 3
}

extract_downtime(){
    psql -h "${SERVICE_IP}" -U app -tAc "
    WITH downtime AS (
        SELECT extract(EPOCH FROM time) - lag(extract(EPOCH FROM time), 1)
        OVER (ORDER BY time) AS lag 
        FROM uptime
    )
    SELECT max(downtime.lag)
    FROM downtime"
}

get_max_downtime(){
    downtime=$(extract_downtime)
    echo "${downtime}" > "${DOWNTIME_FILE}"

    echo -n "MAX Downtime: "
    echo -n "${downtime}"
    echo -n " seconds"
    echo ""
    echo ""
}

main(){
    if [[ $# -lt 2 ]]
    then
        echo "ERROR: missing arguments."
        usage
    fi

    PID=""
    CLUSTER_NAME="${1}"
    SERVICE_IP="${2}"
    KUBECONFIG="${HOME}/.kube/kluster-pi-config"
    PGPASSWORD="$(kubectl get secrets "${CLUSTER_NAME}-app" -o jsonpath='{.data.password}' | base64 -d)"
    PRIMARY="$(kubectl get cluster "${CLUSTER_NAME}" -o custom-columns=:.status.currentPrimary --no-headers)"
    NODE="$(kubectl get pod "${PRIMARY}" -o custom-columns=:.spec.nodeName --no-headers)"
    DOWNTIME_FILE="./downtime_${CLUSTER_NAME}_$(date +%F_%T).out"

    export KUBECONFIG
    export PGPASSWORD

    create_table
    start_writing_table
    sleep 3
    force_delete_primary
    cordon_node
    wait_for_primary
    exec_sql "INSERT INTO uptime(time,note) VALUES(NOW(),'iteration end')"
    get_max_downtime
    uncordon_node

    kill_script
}

main "${@}"
