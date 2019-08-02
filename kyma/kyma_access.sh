echo `kubectl get virtualservice core-console -n kyma-system -o jsonpath='{ .spec.hosts[0] }'`

kubectl get secret admin-user -n kyma-system -o jsonpath="{.data.password}" | base64 --decode | pbcopy