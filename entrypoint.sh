#!/bin/sh -l

if [ "$5" -eq '' ]; then
  if [ "$2" -eq '' ]; then
    echo "Missing 'server-url' parameter!"
    exit 1
  fi

  if [ "$3" -eq '' ]; then
    echo "Missing 'server-ca' parameter!"
    exit 1
  fi

  if [ "$4" -eq '' ]; then
    echo "Missing 'sa-token' parameter!"
    exit 1
  fi

  cat /work/ca.crt > ca.crt
  echo "$3" | base64 -d > ca.crt
  context="local"
  kubectl config set-cluster "$context" --server "$2" --certificate-authority ca.crt --embed-certs=true
  kubectl config set-credentials actions-runner --token "$4"
  kubectl config set-context "$context" --cluster "$context" --user actions-runner --namespace default
  kubectl config use-context "$context"
else
  mkdir -p ~/.kube
  echo "$5" | base64 -d > ~/.kube/config
  context=$(echo "$1" | cut -d'/' -f2)
  kubectl config use-context "$context"
fi

echo "diff<<EOF" >> "$GITHUB_OUTPUT"
echo "$(for var in $(kubectl --context "$context" kustomize "$1" | grep -o '{[^}]*}' | awk -F"[{}]" '{print$2}'); do \
  unset "$var" && export "$var"="$(\
    kubectl --context "$context" get cm cluster-values -n flux-system -o yaml | \
    grep "$var" | \
    awk '{sub(/:/, );$1=$1;print $2}' | \
    tr -d " " | tr -d '"')"; \
  done; \
  kubectl --context "$context" kustomize "$1" | envsubst | \
  kubectl --context "$context" diff -f -\
)" >> "$GITHUB_OUTPUT"
echo "EOF" >> "$GITHUB_OUTPUT"
