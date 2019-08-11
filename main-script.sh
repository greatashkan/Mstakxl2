#sh scrips/k8s-bash.sh \
	&& bash scrips/jenkins.sh \
	&& bash scrips/helminit.sh  \
	&& bash scrips/guestbook.sh  \
	&& bash scrips/nginxinit.sh \
	&& bash scrips/prom-mon.sh \
	&& bash scripts/Headless-svc.sh \
	&& bash scripts/Statefulset-kibana-fluentd.sh \
	&& bash scripts/Headless-svc.sh 

