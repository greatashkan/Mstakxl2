# Mstakx Level 2 tests
Here you could fine the second level of the tests: 
### Requirements
Before installation you must bring up k8s cluster. I bought up a cluster of two nodes. One master and one worker.

## Jenkins Installation

 Install java jdk 8
```
sudo apt install openjdk-8-jdk -y
```

Download and install Jenkins. First add the repo and then the package installation by apt-get

```
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

sudo apt update

sudo apt install Jenkins y

systemctl start jenkins
```

Then open up the webserver by port 8080 to start the jenkins configuration through web ui

```
http://your_server_ip_or_domain:8080
```
cat the below file and paste it to the web ui for password change
```
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
Now Jenkins is ready to use based on your needs


## Instal Guestbook
```
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl create namespace development

kubectl apply -f https://k8s.io/examples/application/guestbook/redis-master-deployment.yaml -n development

kubectl apply -f https://k8s.io/examples/application/guestbook/redis-master-service.yaml -n development
```

## Install Helm
Use helm to automate the installations of applications through Kubernetes

```
sudo add-apt-repository ppa:masterminds/glide && sudo apt-get update

sudo apt-get install glide

cd ~

curl -LO https://git.io/get_helm.sh

chmod 700 get_helm.sh

./get_helm.sh

```
Then you need to create the Tiller Account service to have access to K8S cluster resources
```
kubectl create serviceaccount tiller --namespace kube-system
```
Apply the below yaml file for cluster role binding

```
kubectl create -f tiller-clusterrolebinding.yaml
```
```
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: tiller-clusterrolebinding
subjects:
- kind: ServiceAccount
  name: tiller
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: ""

```
Then upgrade the Tiller  to apply the changes
```
helm init --service-account tiller --upgrade
```
install a Mysql chart for test with some parameters

```
helm install --name Mysql-Helm --set mysqlRootPassword=Qwer@123@, \
mysqlUser=helmuser ,mysqlPassword=Qwer2123, \
mysqlDatabase=mydb  stable/mysql namespace development
```
Now we want to install it via CI server
In Jenkins create a freestyle project. Then in configuration in Build Environment Part enable the checkbox of "Execute shell script on remote host using ssh" and in SSH Site type "ssh@IP:Port" of your remote server. Then in pre built type in your command for run

I use proxy for sanctions
```
export http_proxy=http://user:pass@IP:port
export https_proxy=http://user:pass@IP:port
export no_proxy="127.0.0.1,localhost"
export KUBECONFIG=/etc/kubernetes/admin.conf
helm install --name mysqlhelm --set mysqlRootPassword=Qwer@123@,mysqlUser=helmuser \
,mysqlPassword=Qwer2123,mysqlDatabase=mydb stable/mysql --namespace development
```

## Monitoring the cluster
Run a Nginx deployment and then add the servicemonitor kind for it.

```
kubectl create namespace monitoring

kubectl create deployment nginx --image=nginx -n development
```

```
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  namespaceSelector:
    matchNames:
    - default
  endpoints:
  - port: web
    interval: 30s

------

kubectl apply f servicemonitor.yaml

```


Install Prometheus with Helm

```
helm install stable/prometheus-operator --name prometheus-operator --namespace monitoring
```
If you want to see the panel on localhost forward it to see the prometheus
```
kubectl port-forward -n monitoring prometheus-prometheus-operator-prometheus-0 9090
```

If you want to see the browser on localhost forward it to see the grafana

```
kubectl port-forward $(kubectl get pods --selector=app=grafana \
 -n monitoring --output=jsonpath="{.items..metadata.name}") -n monitoring 3000
```

if you want to nodeport the dashboard and promotheus
```
kubectl -n monitoring get service prometheus-operator-prometheus -o yaml > /home/infra/prom-nodeport.yaml 

```

open the extracted yaml with vi and change the type from clusterIp to NodePort

And then you could access it through its port
```
kubectl apply -f /home/infra/prom-nodeport.yaml -n monitoring
```

You could do it for Grafana too

## Install elasticsearch fluentd
Create the namespace for kube-logging
```
kubectl create namespace kube-logging
```

#### Creating the Headless Service
```
vi elasticsearch_svc.yaml
kubectl create -f elasticsearch_svc.yaml
```
```
kind: Service
apiVersion: v1
metadata:
  name: elasticsearch
  namespace: kube-logging
  labels:
    app: elasticsearch
spec:
  selector:
    app: elasticsearch
  clusterIP: None
  ports:
    - port: 9200
      name: rest
    - port: 9300
      name: inter-node

```
#### Creating the StatefulSet
Before this, add a storage class and add 3 pv. I changed the StorageClassName to manual in the yaml file. Create the of these for dynamic binding

```
mkdir /mnt/elastic
mkdir /mnt/elastic1
mkdir /mnt/elastic2
Kubectl apply f pv-volume.yaml
```
```
kind: PersistentVolume
apiVersion: v1
metadata:
  name: pv-elstic02
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/elastic01"

```

Kubectl apply f statefulset.yaml

```
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-cluster
  namespace: kube-logging
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:7.2.0
        resources:
            limits:
              cpu: 1000m
            requests:
              cpu: 100m
        ports:
        - containerPort: 9200
          name: rest
          protocol: TCP
        - containerPort: 9300
          name: inter-node
          protocol: TCP
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
        env:
          - name: cluster.name
            value: k8s-logs
          - name: node.name
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: discovery.seed_hosts
            value: "es-cluster-0.elasticsearch,es-cluster-1.elasticsearch,es-cluster-2.elasticsearch"
          - name: cluster.initial_master_nodes
            value: "es-cluster-0,es-cluster-1,es-cluster-2"
          - name: ES_JAVA_OPTS
            value: "-Xms512m -Xmx512m"
      initContainers:
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
      - name: increase-vm-max-map
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
      - name: increase-fd-ulimit
        image: busybox
        command: ["sh", "-c", "ulimit -n 65536"]
        securityContext:
          privileged: true
  volumeClaimTemplates:
  - metadata:
      name: data
      labels:
        app: elasticsearch
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: manual
      resources:
        requests:
          storage: 10Gi

```

### Kibana Install

Create the Deploymnet and service of Kibana
Kubectl f apply kibana.yaml

```
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: kube-logging
  labels:
    app: kibana
spec:
  ports:
  - port: 5601
  selector:
    app: kibana
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: kube-logging
  labels:
    app: kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:7.2.0
        resources:
          limits:
            cpu: 1000m
          requests:
            cpu: 100m
        env:
          - name: ELASTICSEARCH_URL
            value: http://elasticsearch:9200
        ports:
        - containerPort: 5601

```
Test the Kibana panel
```
kubectl port-forward kibana-6c9fb4b5b7-plbg2 5601:5601 --namespace=kube-logging
```

#### now create the Fluentd things

```
kubectl create -f fluentd.yaml
```
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: kube-logging
  labels:
    app: fluentd
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluentd
  labels:
    app: fluentd
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - namespaces
  verbs:
  - get
  - list
  - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: fluentd
roleRef:
  kind: ClusterRole
  name: fluentd
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: kube-logging
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-logging
  labels:
    app: fluentd
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      serviceAccount: fluentd
      serviceAccountName: fluentd
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.4.2-debian-elasticsearch-1.1
        env:
          - name:  FLUENT_ELASTICSEARCH_HOST
            value: "elasticsearch.kube-logging.svc.cluster.local"
          - name:  FLUENT_ELASTICSEARCH_PORT
            value: "9200"
          - name: FLUENT_ELASTICSEARCH_SCHEME
            value: "http"
          - name: FLUENTD_SYSTEMD_CONF
            value: disable
        resources:
          limits:
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers

```
Now you could use kibana  to see the logs of every part of the cluster and create custom dashboards


### Demonstrate Blue/Green
I used API to implement blue green test.

create a dockerfile and its files in a directory and push them with the latest tag to a docker hub account
``` 
vi index.html
```
```
<h1>Naghous App V1</h1>
<p>MSTAKX</p>
```
```
default.conf
```
```
server {
    listen       80;
    server_name  localhost;

    #charset koi8-r;
    #access_log  /var/log/nginx/log/host.access.log  main;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}
```
```
vi Docekrfile
```
```
FROM nginx:alpine
COPY default.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
```
```
vi naghous-service.yaml
kubectl apply f naghous-service.yaml
```

```
apiVersion: v1
kind: Service
metadata:
  name: naghous
  labels:
    type: app-service
spec:
  selector:
    app: naghous
    env: green
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
```

#### The deployer have two parts: One part is toggle which changes the environment from blue to green and vice versa. and the deploy part which checks if the image with latest tag is the latest or not. if there is a change it will pull it and deploy it on the environment which is not active. you can call the parts with this addressing:
-----
@app.route('/toggle/<namespace>/<servicename>')
IPaddress:port/toggle/default/naghous/
-----
This will trigger the environment change.

#### with the below format you call on the deployment and will terminate the old deployment and will create new ones with the latest image.
----
@app.route('/deploy/<namespace>/<deployment_name>')
IPaddress:port/deploy/default/naghous
----

```
deployer-blue-green.py
```
```
from flask import Flask, jsonify
from flasgger import Swagger
from kubernetes import client, config
from time import sleep
app = Flask(__name__)
swagger = Swagger(app)

config.load_kube_config()
k8s_v1 = client.CoreV1Api()

def active_environment(namespace,servicename):
    api_response = k8s_v1.read_namespaced_service(servicename,namespace,pretty="true")
    active_env=api_response.spec.selector['env']
    return active_env

@app.route('/env/<namespace>/<servicename>/')
def get_active_environment(namespace,servicename):
    active_env=active_environment(namespace,servicename)
    result = { "namespace": namespace,
                    "name": servicename,
                    "active_env": active_env }

    return jsonify(result)

@app.route('/toggle/<namespace>/<servicename>')
def do_toggle_environment(namespace,servicename):
    active_env=active_environment(namespace,servicename)
    if (active_env == 'green'):
        new_env= 'blue'
    else:
        new_env= 'green'
    api_response = k8s_v1.read_namespaced_service(servicename,namespace,pretty="true")
    body = {"spec":{"selector": { "env": new_env } }}
    try:
        api_response = k8s_v1.patch_namespaced_service(servicename, namespace, body)
        return jsonify({"message":"Toggeld Successfully"})
    except Exception as e:
        return jsonify({"message":"Toggle Failed","Error":str(e),"Active_Env": active_environment(namespace,servicename)})

def create_deployment(namespace,deployment_name,new_env):

    container = client.V1Container(
    name="naghous",
    image="greatashkan/naghous:latest",
    image_pull_policy="Always",
    ports=[client.V1ContainerPort(container_port=80)])
    template = client.V1PodTemplateSpec(
    metadata=client.V1ObjectMeta(labels={"app": deployment_name,"env": new_env}),
    spec=client.V1PodSpec(containers=[container]))
    spec = client.AppsV1beta1DeploymentSpec(
        replicas=2,
        template=template)
    body = client.AppsV1beta1Deployment(
      api_version="apps/v1beta1",
        kind="Deployment",
        metadata=client.V1ObjectMeta(name="{}-{}".format(deployment_name,new_env)),
        spec=spec)
    try:
        api_response = client.AppsV1beta1Api().create_namespaced_deployment(namespace, body)
        return jsonify({"Message": str(api_response)})
    except Exception as e:
        return jsonify({"Error": str(e)})
def delete_deployment(namespace,deployment_name):
    try:
        api_response = client.AppsV1beta1Api().delete_namespaced_deployment(deployment_name, namespace)
        print(api_response)
        return jsonify({"Message": str(api_response)})
    except Exception as e:
        return jsonify({"Error": str(e)})

@app.route('/deploy/<namespace>/<deployment_name>')
def do_deploy(namespace,deployment_name):
    active_env=active_environment(namespace,deployment_name)
    if (active_env == 'green'):
        new_env= 'blue'
    else:
        new_env= 'green'
    result= delete_deployment(namespace,"{}-{}".format(deployment_name,new_env))
    print(result)
    sleep(10)
    return create_deployment(namespace,deployment_name,new_env)
app.run(host="0.0.0.0")
```

Now after every push you can call the deploy Api and have the newest change on the deployment and after a time toggle to the color that is the most stable.

