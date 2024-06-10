#!/bin/bash

force_delete_pods() {
    start=$1
    end=$2
    for i in $(seq "$start" "$end"); do
        kubectl annotate pod kafka-"$i" confluent.io/disable-blocking-kafka-pod-deletion-webhook-pod-annotation=true
        kubectl delete pod/kafka-"$i"
    done
}
