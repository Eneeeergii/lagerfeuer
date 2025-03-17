#!/bin/bash

set -e  # Beendet das Skript bei Fehlern

read -rp "Bitte gebe den Namespace ein, indem die Operatoren installiert werden sollen: " NAMESPACE

# Prüfen, ob der Namespace bereits existiert
echo "========================================"
echo "📌 Prüfe Namespace: $NAMESPACE"
echo "========================================"
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "✅ Namespace '$NAMESPACE' existiert bereits. Überspringe Erstellung."
else
    echo "🔧 Erstelle Namespace '$NAMESPACE'..."
    kubectl create namespace "$NAMESPACE"
fi

# Postgres Operator Installation
echo "========================================"
echo "📌 PostgreSQL Operator Installation"
echo "========================================"
echo "➕ Füge das Postgres Operator Chart-Repository hinzu..."

/usr/local/bin/helm repo add postgres-operator-charts \
    https://opensource.zalando.com/postgres-operator/charts/postgres-operator
if /usr/local/bin/helm list --namespace "$NAMESPACE" | grep -q "postgres-operator"; then
    echo "🔄 Postgres Operator ist bereits installiert. Führe Upgrade durch..."
    /usr/local/bin/helm upgrade --namespace "$NAMESPACE" postgres-operator postgres-operator-charts/postgres-operator
else
    original_priorityclass="postgres-operator-pod"
    temp_file="postgres-priority.yaml"
    new_priorityclass="${original_priorityclass}${namespace}"

    # Check if the PriorityClass exists
    if kubectl get priorityclass "$original_priorityclass" &> /dev/null; then
        echo "✅ PriorityClass '$original_priorityclass' found. Creating a new modified PriorityClass..."
        
        # Export the existing PriorityClass
        kubectl get priorityclass "$original_priorityclass" -o yaml > "$temp_file"

        # Modify the name and Helm annotation
        sed -i "s/name: $original_priorityclass/name: $new_priorityclass/g" "$temp_file"
        sed -i "s/meta.helm.sh\/release-namespace: .*/meta.helm.sh\/release-namespace: $NAMESPACE/g" "$temp_file"

        echo "✅ Updated PriorityClass YAML:"
        cat "$temp_file"

        # Apply the new PriorityClass
        kubectl apply -f "$temp_file"

        echo "🎉 New PriorityClass '$new_priorityclass' has been created and applied successfully!"
    else
        echo "🚀 PriorityClass '$original_priorityclass' existiert nicht. Installiere Operator mit neuer default PriorityClass."
        helm install --namespace "$NAMESPACE" postgres-operator postgres-operator-charts/postgres-operator
    fi
fi
sleep 15

# Postgres Operator UI Installation
echo "========================================"
echo "📌 PostgreSQL Operator UI Installation"
echo "========================================"
echo "➕ Füge das Postgres Operator UI Chart-Repository hinzu..."
/usr/local/bin/helm repo add postgres-operator-ui-charts \
    https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui

if /usr/local/bin/helm list --namespace "$NAMESPACE" | grep -q "postgres-operator-ui"; then
    echo "🔄 Postgres Operator UI ist bereits installiert. Führe Upgrade durch..."
    /usr/local/bin/helm upgrade --namespace "$NAMESPACE" postgres-operator-ui postgres-operator-ui-charts/postgres-operator-ui
else
    echo "🚀 Installiere den Postgres Operator UI..."
    /usr/local/bin/helm install --namespace "$NAMESPACE" postgres-operator-ui postgres-operator-ui-charts/postgres-operator-ui
fi

# Vorhandenen Service anpassen
echo "========================================"
echo "📌 Anpassen des bestehenden PostgreSQL Operator UI Service"
echo "========================================"

read -p "🔧 Bitte die LoadBalancer IP eingeben: " LOADBALANCER_IP
read -p "🔧 Bitte den Port für den Service eingeben: " SERVICE_PORT

kubectl patch service postgres-operator-ui -n "$NAMESPACE" --type='merge' -p "
{
  \"spec\": {
    \"type\": \"LoadBalancer\",
    \"loadBalancerIP\": \"$LOADBALANCER_IP\",
    \"ports\": [
      {
        \"port\": $SERVICE_PORT,
        \"targetPort\": $SERVICE_PORT,
        \"protocol\": \"TCP\"
      }
    ]
  }
}"

echo "🔍 Überprüfe, ob der Service erfolgreich aktualisiert wurde..."
sleep 5
kubectl get services -n "$NAMESPACE" | grep postgres-operator-ui

# YAML speichern
echo "========================================"
echo "📌 Speichere die Service YAML unter Deployments"
echo "========================================"

# Abrufen der Service-Konfiguration & ConfigMap Konfiguration und in eine YAML-Datei speichern
kubectl get service postgres-operator-ui -n "$NAMESPACE" -o yaml > Deployments/postgres/postgres-operator-ui-service.yaml

echo "Die Service YAML wurde erfolgreich unter Deployments/postgres-operator-ui-service.yaml gespeichert."

echo "========================================"
echo "✅ Helm, der Postgres Operator und die Postgres Operator UI wurden erfolgreich installiert oder aktualisiert!"
echo "========================================"