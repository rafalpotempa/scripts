APP_NAME="github-connector-app"


helm install \
	--set container.image=kymaflyingseals/github-connector:latest \
	--set kymaAddress=34.77.213.54.xip.io -n github-connector-error-handling-test \
	--namespace  . --tls