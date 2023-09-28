#!/bin/bash

SERVER=""
USER=""
PASSWD=""
LOC=""
CSI_TAG="latest-1.3.0"
CSI_DEPLOYMENT_NAME="cte-csi-deployment"

# This values must match the values in the node server and controller yaml files
DEFAULT_SERVER="gitlabent.thalesesec.com:5050"
DEFAULT_LOC="agents/core-dev/cte-k8-builder"

DEPLOY_OPTIONS=""

set_aws_passwd()
{
        if ! [ -x "$(command -v aws)" ]; then
            echo "Error: 'aws' is not installed or not in PATH." >&2
            exit 1
        fi
        USER="AWS"
        PASSWD=`aws ecr get-login-password --region us-east-1`
        if [ $? -ne 0 ]; then
            exit 1;
        fi
        DEPLOY_OPTIONS="${DEPLOY_OPTIONS} --user=${USER} --passwd=${PASSWD}"
}

start()
{
    if [[ "${DEPLOY_OPTIONS}" == *"remove"* ]]; then
        if [[ "${DEPLOY_OPTIONS}" != *"operator"* ]]; then
            # Remove cte-csi using helm
            ./deploy.sh --remove
        else
            # Remove using operator, pass on namespace info if supplied
            ./deploy.sh ${DEPLOY_OPTIONS}
        fi
        exit 0
    fi

    if [ -z "${SERVER}" ]; then
        SERVER=${DEFAULT_SERVER}
    fi
    if [ -z "${LOC}" ]; then
        LOC=${DEFAULT_LOC}
    fi
    # Remove repeating /
    IMAGE=$(echo "${SERVER}/${LOC}/cte_csi" | tr -s /)

    # Set the HELM_CMD variable with options for internal deploy options
    # This will be used in the actual deploy script.
    # If not operator based install and if not remove, then call helm install
    # the deploy.sh script checks if HELM_CMD is defined and initialized. If it is, then
    # the existing definition is used, where we configure the internal container registry
    if [ "${DEPLOY_OPTIONS}" != *"operator"* ] && [ "${DEPLOY_OPTIONS}" != *"remove"* ]; then
        # "upgrade --install" will install if no prior install exists, else upgrade
        export HELM_CMD="helm upgrade --install ${DEPLOY_OPTIONS} --set image.cteCsiImage=${IMAGE}"
    fi

    # Call the actual deploy script with options set for internal deploy
    ./deploy.sh ${DEPLOY_OPTIONS}
}

usage()
{
    echo  "Options :"
    echo  "-s | --server=   Container registry server value."
    echo  "                             Default: gitlabent.thalesesec.com:5050"
    echo  "-u | --user=     Container registry user name value."
    echo  "-p | --passwd=   Container registry user password value."
    echo  "-l | --loc=      Location of image in the server"
    echo  "                             Default: agents/core-dev/cte-k8-builder"
    echo  "-n | --name=      name of image in the server"
    echo  "                             Default: cte_csi"
    echo  "-t | --tag=      Tag of image on the server"
    echo  "                             Default: latest"
    echo  "-a | --awspw     Generate short term password for image repo"
    echo  "-r | --remove    Undeploy the CSI driver and exit"
    echo  "-o | --operator  Deploy CTE-K8s Operator and CSI driver"
    echo  "--operator-ns=   The namespace in which to deploy the Operator"
    echo  "--cte-ns=        The namespace in which to deploy the CSI driver"
}

# main
if [ $# -eq 0 ]; then
    echo "Please provide the arguments."
    echo ""
#    usage
#    exit 1
fi

L_OPTS="server:,user:,passwd:,loc:,name:,tag:,awspw,remove,help,operator-ns:,cte-ns:,operator"
S_OPTS="s:u:p:l:n:t:arho"
options=$(getopt -a -l ${L_OPTS} -o ${S_OPTS} -- "$@")
#if [ $? -ne 0 ]; then
#        exit 1
#fi
eval set -- "$options"

while true ; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -s|--server)
            SERVER=${2}
            shift 2
            ;;
        -u|--user)
            USER=${2}
            shift 2
            DEPLOY_OPTIONS="${DEPLOY_OPTIONS} --user=${USER}"
            ;;
        -p|--passwd)
            PASSWD=${2}
            DEPLOY_OPTIONS="${DEPLOY_OPTIONS} --passwd=${PASSWD}"
            shift 2
            ;;
        -l|--loc)
            LOC=${2}
            shift 2
            ;;
        -t|--tag)
            CSI_TAG=${2}
            DEPLOY_OPTIONS="${DEPLOY_OPTIONS} --tag=${CSI_TAG}"
            DEPLOY_OPTIONS="${DEPLOY_OPTIONS} -set image.cteCsiTag=${CSI_TAG}"
            shift 2
            ;;
        -a|--awspw)
            set_aws_passwd
            shift
            ;;
        -r|--remove)
            DEPLOY_OPTIONS="${DEPLOY_OPTIONS} --remove"
            shift
            ;;
       -o|--operator)
            DEPLOY_OPTIONS="${DEPLOY_OPTIONS} --operator"
            shift
            ;;
       --operator-ns)
            OPERATOR_NS=${2}
            DEPLOY_OPTIONS="${DEPLOY_OPTIONS} --operator-ns=${OPERATOR_NS}"
            shift 2
            ;;
       --cte-ns)
            CSI_NS=${2}
            DEPLOY_OPTIONS="${DEPLOY_OPTIONS} --cte-ns=${CSI_NS}"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo -n "unknown option: ${1}"
            exit 1
            ;;

    esac
done

start
