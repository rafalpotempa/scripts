tmpfile=$(mktemp /tmp/temp-cert.XXXXXX) \
&& kubectl get configmap net-global-overrides -n kyma-installer -o jsonpath='{.data.global\.ingress\.tlsCrt}' | base64 --decode > $tmpfile \
&& sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $tmpfile \
&& rm $tmpfile

echo `kubectl get virtualservice core-console -n kyma-system -o jsonpath='{ .spec.hosts[0] }'`

kubectl get secret admin-user -n kyma-system -o jsonpath="{.data.password}" | base64 --decode | pbcopy