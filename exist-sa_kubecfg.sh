# csaroka@vmware.com
# Note: kubeconfig generated based on user's current-context
# Note: Before running, create a service account
# $ chmod +x <filename>
# $ ./<filename> <service account name>
#
set -e
set -o pipefail

if [[ -z "$1" ]] || [[ -z "$2" ]]; then
 echo "usage: $0 <Existing Service Account Name> <Existing Namespace>"
 exit 1
fi

# your server name goes here
# server=https://k8slabapi.lab.local:8443
# username=jenkins
currentcontext=$(kubectl config view -o jsonpath='{.current-context}')
server=$(kubectl config view -o jsonpath='{.clusters[?(@.name == "'${currentcontext}'")].cluster.server}')
secretname=$(kubectl get sa $1 -n $2 -o jsonpath='{.secrets[*].name}')
ca=$(kubectl get secret/$secretname -n $2 -o jsonpath='{.data.ca\.crt}')
token=$(kubectl get secret/$secretname -n $2 -o jsonpath='{.data.token}' | base64 --decode)
# namespace=$(kubectl get secret/$secretname -o jsonpath='{.data.namespace}' | base64 --decode)
echo "
apiVersion: v1
kind: Config
clusters:
- name: ${currentcontext}
  cluster:
    certificate-authority-data: ${ca}
    server: ${server}
contexts:
- name: ${currentcontext}
  context:
    cluster: ${currentcontext}
    namespace: ${2} 
    user: ${1}
current-context: ${currentcontext}
users:
- name: ${1}
  user:
    token: ${token}
" > $1"-sa.kubeconfig"
