APP_NAME="github-connector-app"


helm install \
	--set container.image=kymaflyingseals/github-connector:1.1.5 \
	--set kymaAddress=34.77.213.54.xip.io \
	-n github-connector \
	--namespace  . --tls