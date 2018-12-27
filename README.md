# kubernetes-jenkins
Integrate Jenkins with PKS provisioned Kubernetes Cluster

## Prepare the Kubernetes Cluster and Chart Values

### Clone the repo to a local directory
$ git clone https://github.com/csaroka/kubernetes-jenkins.git
$ cd kubernetes-jenkins

### Create the project Namespace
`$ kubectl create ns jenkins` \
`$ kubectl set-context <CONTEXT_NAME> namespace=jenkins`

### Prepare Persistance Storage
#### Create a storage class
`$ cat jenkins-sc.yaml`
```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: jenkins-disk
provisioner: kubernetes.io/vsphere-volume
parameters:
    diskformat: thin
```
`$ kubectl apply -f jenkins-sc.yaml` \
`$ kubectl get sc`

#### Create a persistant volume claim:
`$ cat jenkins-pvc.yaml`
```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: jenkins-data
  annotations:
    volume.beta.kubernetes.io/storage-class: jenkins-disk
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```
`$ kubectl apply -f jenkins-pvc.yaml`
`$ kubectl get pvc`

### (Optional) Pull the Images and Push to a Private Registry. If pulling direct from public registry, skip this step.
`$ docker pull jenkins/jenkins:lts` \
`$ docker tag jenkins/jenkins <Private Registry FQDN>/<Project>/jenkins-master:v1` \
`$ docker push <Private Registry FQDN>/<Project>/jenkins-master:v1` 

`$ docker pull jenkins/jnlp-slave` \
`$ docker tag jenkins/jnlp-slave <Private Registry FQDN>/<Project>/jenkins-slave:v1`\
`$ docker push <Private Registry FQDN>/<Project>/jenkins-slave:v1` 

### Install Helm Client and Tiller Server

Helm  
https://docs.helm.sh/using_helm/#installing-helm 

Apply Tiller RBAC policy

`$ cat tiller-rbac.yaml`
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
```

`$ kubectl apply -f tiller-rbac.yaml`

Deploy Tiller to the Cluster \
`$ helm init --service-account tiller`

### Prepare the Jenkins Helm Chart values.yaml

`$ cd jenkins` \
Open `values.yaml` with a text editor

#### Identify Jenkins Container Images' Location
Run find function for "image"

If pulling images from a private registry, replace the following intances with the appropriate path:
```
Master:
  Image: "harbor.lab.local/jenkins/jenkins-master"
  ImageTag: "v1"
Agent:
  Image: "harbor.lab.local/jenkins/jenkins-slave"
  ImageTag: "v1"
```
If pulling images direct from public registry, comment out the private registry paths and uncomment the community chart defaults
```
Master:
# Image: "harbor.lab.local/jenkins/jenkins-master"
# ImageTag: "v1"
  Image: "jenkins/jenkins"
  ImageTag: "lts"
Agent:
# Image: "harbor.lab.local/jenkins/jenkins-slave"
# ImageTag: "v1"
  Image: jenkins/jnlp-slave
  ImageTag: 3.10-1
```
If behind a proxy, uncomment and update the paths
```
# InitContainerEnv:
#   - name: http_proxy
#     value: "http://192.168.64.1:3128"
# ContainerEnv:
#   - name: http_proxy
#     value: "http://192.168.64.1:3128"
```
#### Change the Admin Password
```
AdminPassword: 'VMware1!'
```
#### Configure the Ingress Resource

##### Set the Ingress Hostname
>Note: The hostname is customizable but the domain needs to match cluster's ingress controller's wildcard record in DNS. For example, *.pksk8s01apps.lab.local
```
HostName: jenkins.pksk8s01apps.lab.local
```
##### (Optional) Set the path
```
JenkinsUriPrefix: "/jenkins"
```

#### (Optional) Use LoadBalancer, as opposed to a Ingress Resource
Change the ServiceType from:
```
ServiceType: ClusterIP
```
to 
```
ServiceType: LoadBalancer
```

Comment out Ingress Hostname and URI Prefix: 
```
# HostName: jenkins.pksk8s01apps.lab.local
# JenkinsUriPrefix: "/jenkins"
```
#### Configure Persistance

Verify claim name matches PVC created above
```
Persistence:
  ExistingClaim: "jenkins-data"
```
Verify class name matches Storage Class created above
```
Persistence:
  StorageClass: "jenkins-disk"
```

Save changes to `values.yaml` and close

## Install the Chart to the Kubernetes Cluster

`$ cd ..` \
or `cd` to the directory containing the jenkins chart directory

Use `$ kubectl config view` to verify context and namespace or set with \
`$ kubectl set-context <CONTEXT_NAME> namespace=jenkins`

### Use the Helm client to install the chart to the cluster
`$ helm install --name=jenkins ./jenkins`

```
NAME:   jenkins
LAST DEPLOYED: Thu Dec 27 18:22:32 2018
NAMESPACE: jenkins
STATUS: DEPLOYED

RESOURCES:
==> v1/ClusterRoleBinding
NAME                  AGE
jenkins-role-binding  0s

==> v1/Service
NAME           TYPE       CLUSTER-IP      EXTERNAL-IP  PORT(S)    AGE
jenkins-agent  ClusterIP  10.100.200.215  <none>       50000/TCP  0s
jenkins        ClusterIP  10.100.200.15   <none>       8080/TCP   0s

==> v1/Deployment
NAME     DESIRED  CURRENT  UP-TO-DATE  AVAILABLE  AGE
jenkins  1        1        1           0          0s

==> v1beta1/Ingress
NAME     HOSTS                           ADDRESS           PORTS  AGE
jenkins  jenkins.pksk8s01apps.lab.local  10.12.0.6,100...  80     0s

==> v1/Pod(related)
NAME                      READY  STATUS    RESTARTS  AGE
jenkins-7d48db75c5-2mpn9  0/1    Init:0/1  0         0s

==> v1/Secret
NAME     TYPE    DATA  AGE
jenkins  Opaque  2     0s

==> v1/ConfigMap
NAME           DATA  AGE
jenkins        5     0s
jenkins-tests  1     0s

==> v1/ServiceAccount
NAME     SECRETS  AGE
jenkins  1        0s


NOTES:
1. Get your 'admin' user password by running:
  printf $(kubectl get secret --namespace jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo

2. Visit http://jenkins.pksk8s01apps.lab.local

3. Login with the password from step 1 and the username: admin

For more information on running Jenkins on Kubernetes, visit:
https://cloud.google.com/solutions/jenkins-on-container-engine
Configure the Kubernetes plugin in Jenkins to use the following Service Account name jenkins using the following steps:
  Create a Jenkins credential of type Kubernetes service account with service account name jenkins
  Under configure Jenkins -- Update the credentials config in the cloud section to use the service account credential you created in the step above.
```
Run `$ watch kubectl get pods` to monitor the pod creation status or simply run `kubectl get pods` until the output reports the pod is "Running", for instance:
```
NAME                       READY   STATUS    RESTARTS   AGE
jenkins-7d48db75c5-2mpn9   1/1     Running   0          5m
```
## Access the Jenkins Web UI for Initial Configuration

>The `NOTE No 2.` from the helm install output does not account for a URI Prefix, if set in the values.yaml. If you did not change the value.yaml option: `JenkinsUriPrefix: "/jenkins"`, the `NOTE No 2.` should actually indicate to: \
`Visit http://jenkins.pksk8s01apps.lab.local/jenkins`

Open a web browser to (parameters from values.yaml):
`http://<HostName>/<JenkinsUriPrefix>`

![alt text](https://github.com/csaroka/kubernetes-jenkins/blob/master/images/jenkins-welcome.png)

Login with credentials
User: Admin
Password: VMware1!

> Note: If you forgot the password, run the command `$ printf $(kubectl get secret --namespace jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo`







