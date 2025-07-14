#####################################
# Building tools version(s)
# If you have a multi-stage Dockerfile and you're working with build arguments
# in multiple stages, you have to be aware that they are only available
# in the stage where they are defined. This means that you can't use an
# argument defined in the first stage in the second stage.
#####################################
# renovate: datasource=repology depnameprefix=alpine_3_22/bash versioning=loose
ARG BASH_VERSION=5.2.37-r0
# renovate: datasource=repology depnameprefix=alpine_3_22/curl versioning=loose
ARG CURL_VERSION=8.14.1-r1
# renovate: datasource=repology depnameprefix=alpine_3_22/git versioning=loose
ARG GIT_VERSION=2.49.1-r0
# renovate: datasource=repology depnameprefix=alpine_3_22/jq versioning=loose
ARG JQ_VERSION=1.8.0-r0
# renovate: datasource=repology depnameprefix=alpine_3_22/openssh-client-default versioning=loose
ARG OPENSSH_CLIENT_DEFAULT_VERSION=10.0_p1-r7
# renovate: datasource=repology depnameprefix=alpine_3_22/perl versioning=loose
ARG PERL_VERSION=5.40.2-r0
# renovate: datasource=repology depnameprefix=alpine_3_22/su-exec versioning=loose
ARG SU_EXEC_VERSION=0.2-r3

ARG PYTHON_VENV="/opt/python_venv"

#####################################
# Arguments
#####################################
ARG TAG=3.13.5-alpine3.22@sha256:9b4929a72599b6c6389ece4ecbf415fd1355129f22bb92bb137eea098f05e975
FROM python:${TAG} AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TOOLS_VERSION_FILE="tools_versions_info"
ARG PYTHON_VENV

#####################################
# Installed tools version(s)
#####################################
ARG PRE_COMMIT_VERSION=${PRE_COMMIT_VERSION:-latest}
ARG CHECKOV_VERSION=${CHECKOV_VERSION:-false}
ARG TERRAFORM_VERSION=${TERRAFORM_VERSION:-latest}
ARG TERRAFORM_DOCS_VERSION=${TERRAFORM_DOCS_VERSION:-false}
ARG TERRAGRUNT_VERSION=${TERRAGRUNT_VERSION:-false}
ARG TFLINT_VERSION=${TFLINT_VERSION:-false}
ARG ANSIBLE_VERSION=${ANSIBLE_VERSION:-false}
ARG ANSIBLE_LINT_VERSION=${ANSIBLE_LINT_VERSION:-false}

ARG BASH_VERSION
ARG CURL_VERSION
ARG JQ_VERSION

# renovate: datasource=pypi depName=colorlog
ARG COLORLOG_VERSION=6.9.0
# renovate: datasource=pypi depName=pip
ARG PIP_VERION=25.1.1
# renovate: datasource=pypi depName=setuptools
ARG SETUPTOOLS_VERSION=80.9.0

COPY scripts/assets/ /assets/

WORKDIR /bin_dir
ENV PATH="$PATH:/bin_dir:${PYTHON_VENV}/bin"

#####################################
# Create builder image
#####################################
# Activate python venv
RUN python3 -m venv ${PYTHON_VENV}

# Upgrade packages for be able get latest Checkov (pip, setuptools)
# Install colorlog for properly formatted log
RUN apk add --no-cache \
  bash=${BASH_VERSION} \
  curl=${CURL_VERSION} \
  jq=${JQ_VERSION} && \
  ${PYTHON_VENV}/bin/pip3 install --no-cache-dir --upgrade \
  pip==${PIP_VERION} \
  setuptools==${SETUPTOOLS_VERSION} \
  colorlog==${COLORLOG_VERSION}

RUN touch /.env &&\
  /assets/pre-commit.sh &&\
  /assets/ansible.sh &&\
  /assets/ansible-lint.sh &&\
  /assets/ansible-galaxy.sh &&\
  /assets/checkov.sh &&\
  /assets/terraform-docs.sh &&\
  /assets/terraform.sh &&\
  /assets/terragrunt.sh &&\
  /assets/tflint.sh

RUN cat $TOOLS_VERSION_FILE

#####################################
# Create final image
#####################################
FROM python:${TAG}

ARG BASH_VERSION
ARG CURL_VERSION
ARG GIT_VERSION
ARG JQ_VERSION
ARG OPENSSH_CLIENT_DEFAULT_VERSION
ARG PERL_VERSION
ARG SU_EXEC_VERSION
ARG PYTHON_VENV

ENV PATH="$PATH:${PYTHON_VENV}/bin"
ENV ANSIBLE_COLLECTIONS_PATH="${PYTHON_VENV}/bin/collections"
ENV ANSIBLE_ROLES_PATH="${PYTHON_VENV}/bin/roles"

# Install dependencies
RUN apk add --no-cache \
  bash=${BASH_VERSION} \
  curl=${CURL_VERSION} \
  git=${GIT_VERSION} \
  jq=${JQ_VERSION} \
  openssh-client-default=${OPENSSH_CLIENT_DEFAULT_VERSION} \
  perl=${PERL_VERSION} \
  su-exec=${SU_EXEC_VERSION} &&\
  # Fix git runtime fatal:
  # unsafe repository ('/lint' is owned by someone else)
  git config --global --add safe.directory /lint

# Copy tools
## Copy binaries
COPY --from=builder \
  /bin_dir/ \
  /usr/bin/

## Copy python packages
COPY --from=builder \
  ${PYTHON_VENV} \
  ${PYTHON_VENV}

# Add user to able to use ssh credentials
RUN adduser -D user && \
  mkdir -p /home/user/.ssh && \
  chown -R user:user /home/user/.ssh

### Copy pre-commit packages
COPY scripts/entrypoint /entrypoint
COPY scripts/pre-commit-custom /pre-commit-custom
COPY scripts/pre-commit-custom /post-checkout-custom

ENTRYPOINT [ "/entrypoint" ]
