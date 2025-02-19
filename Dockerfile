#####################################
# Building tools version(s)
# If you have a multi-stage Dockerfile and you're working with build arguments
# in multiple stages, you have to be aware that they are only available
# in the stage where they are defined. This means that you can't use an
# argument defined in the first stage in the second stage.
#####################################
# renovate: datasource=repology depnameprefix=alpine_3_17/bash versioning=loose
ARG BASH_VERSION=5.2.15-r0
# renovate: datasource=repology depnameprefix=alpine_3_17/curl versioning=loose
ARG CURL_VERSION=8.9.0-r0
# renovate: datasource=repology depnameprefix=alpine_3_17/gcc versioning=loose
ARG GCC_VERSION=12.2.1_git20220924-r4
# renovate: datasource=repology depnameprefix=alpine_3_17/git versioning=loose
ARG GIT_VERSION=2.39.5-r0
# renovate: datasource=repology depnameprefix=alpine_3_17/jq versioning=loose
ARG JQ_VERSION=1.6-r2
# renovate: datasource=repology depnameprefix=alpine_3_17/libffi-dev versioning=loose
ARG LIBFFI_DEV_VERSION=3.4.4-r0
# renovate: datasource=repology depnameprefix=alpine_3_17/musl-dev versioning=loose
ARG MUSL_DEV_VERSION=1.2.3-r6
# renovate: datasource=repology depnameprefix=alpine_3_17/openssh-client-default versioning=loose
ARG OPENSSH_CLIENT_DEFAULT_VERSION=9.1_p1-r6
# renovate: datasource=repology depnameprefix=alpine_3_17/perl versioning=loose
ARG PERL_VERSION=5.36.2-r0
# renovate: datasource=repology depnameprefix=alpine_3_17/su-exec versioning=loose
ARG SU_EXEC_VERSION=0.2-r2

#####################################
# Arguments
#####################################
ARG TAG=3.12.0-alpine3.17@sha256:fc34b07ec97a4f288bc17083d288374a803dd59800399c76b977016c9fe5b8f2
FROM python:${TAG} AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TOOLS_VERSION_FILE="tools_versions_info"

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
ARG GCC_VERSION
ARG JQ_VERSION
ARG LIBFFI_DEV_VERSION
ARG MUSL_DEV_VERSION

# renovate: datasource=pypi depName=colorlog
ARG COLORLOG_VERSION=6.8.0
# renovate: datasource=pypi depName=pip
ARG PIP_VERION=24.2
# renovate: datasource=pypi depName=setuptools
ARG SETUPTOOLS_VERSION=75.2.0

COPY scripts/assets/ /assets/

WORKDIR /bin_dir
ENV PATH="$PATH:/bin_dir"

#####################################
# Create builder image
#####################################
# Upgrade packages for be able get latest Checkov (pip, setuptools)
# Install colorlog for properly formatted log
RUN apk add --no-cache \
      bash=${BASH_VERSION} \
      curl=${CURL_VERSION} \
      gcc=${GCC_VERSION} \
      jq=${JQ_VERSION} \
      libffi-dev=${LIBFFI_DEV_VERSION} \
      musl-dev=${MUSL_DEV_VERSION} &&\
    python3 -m pip install --no-cache-dir --upgrade \
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
ARG GCC_VERSION
ARG GIT_VERSION
ARG JQ_VERSION
ARG MUSL_DEV_VERSION
ARG OPENSSH_CLIENT_DEFAULT_VERSION
ARG PERL_VERSION
ARG SU_EXEC_VERSION

ENV ANSIBLE_COLLECTIONS_PATH="/usr/bin/collections"
ENV ANSIBLE_ROLES_PATH="/usr/bin/roles"

# Install dependencies
RUN apk add --no-cache \
      bash=${BASH_VERSION} \
      curl=${CURL_VERSION} \
      gcc=${GCC_VERSION} \
      git=${GIT_VERSION} \
      jq=${JQ_VERSION} \
      musl-dev=${MUSL_DEV_VERSION} \
      openssh-client-default=${OPENSSH_CLIENT_DEFAULT_VERSION} \
      perl=${PERL_VERSION} \
      su-exec=${SU_EXEC_VERSION} &&\
    # Fix git runtime fatal:
    # unsafe repository ('/lint' is owned by someone else)
    git config --global --add safe.directory /lint

# Copy tools
## pre-commit, hooks and binaries
COPY --from=builder \
    /usr/local/bin/pre-commit \
    /usr/local/bin/ansible* \
    /bin_dir/ \
    /usr/local/bin/checkov* \
    /usr/bin/

## Copy pre-commit packages
COPY --from=builder \
  /usr/local/lib/python3.12/site-packages/ \
  /usr/local/lib/python3.12/site-packages/

# Add user to able to use ssh credentials
RUN adduser -D user && \
  mkdir -p /home/user/.ssh && \
  chown -R user:user /home/user/.ssh

COPY scripts/entrypoint /entrypoint
COPY scripts/pre-commit-custom /pre-commit-custom
COPY scripts/pre-commit-custom /post-checkout-custom

ENTRYPOINT [ "/entrypoint" ]
