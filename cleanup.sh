#!/bin/bash
echo "Enter the name of Service Mesh Control Plane project: "
read CONTROL_PLANE
echo

echo "Enter the name of Service Mesh Data Plane project: "
read DATA_PLANE
echo

for smcp in $(oc get smcp -n $CONTROL_PLANE --no-headers -o=custom-columns='DATA:metadata.name')
do
    oc delete smcp/$smcp -n $CONTROL_PLANE
done

oc delete all --all -n $DATA_PLANE
oc delete project $CONTROL_PLANE
oc delete project $DATA_PLANE