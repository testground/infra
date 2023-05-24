#!/bin/bash

cd $(dirname "$0")

mkdir -p tmp
curl -o tmp/dashboards.yaml https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/grafana-dashboardDefinitions.yaml

names=$(yq '.items[].metadata.name' tmp/dashboards.yaml)
files=$(yq '.items[].data | keys | .[]' tmp/dashboards.yaml)

readarray -t arr_name <<<"$names"
readarray -t arr_file <<<"$files"

size=${#arr_name[@]}

echo "" > dashboards.yaml

for (( i=0; i<=$size-1; i++ ))
do
    echo $i
    name=${arr_name[$i]}
    file=${arr_file[$i]}
    echo $name
    echo $file

    export name file

    cat dashboards.yaml.tmpl | envsubst >> dashboards.yaml
done

rm -r tmp
