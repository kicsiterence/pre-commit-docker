ARG TAG=3.12.0-alpine3.17@sha256:fc34b07ec97a4f288bc17083d288374a803dd59800399c76b977016c9fe5b8f2
FROM python:${TAG} AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TOOLS_VERSION_FILE="tools_versions_info"

# Install tools
ARG PRE_COMMIT_VERSION=${PRE_COMMIT_VERSION:-latest}
ARG CHECKOV_VERSION=${CHECKOV_VERSION:-false}
ARG TERRAFORM_VERSION=${TERRAFORM_VERSION:-latest}
ARG TERRAFORM_DOCS_VERSION=${TERRAFORM_DOCS_VERSION:-false}
ARG TERRAGRUNT_VERSION=${TERRAGRUNT_VERSION:-false}
ARG TFLINT_VERSION=${TFLINT_VERSION:-false}
ARG ANSIBLE_VERSION=${ANSIBLE_VERSION:-false}
ARG ANSIBLE_LINT_VERSION=${ANSIBLE_LINT_VERSION:-false}

COPY scripts/assets/ /assets/

WORKDIR /bin_dir
ENV PATH="$PATH:/bin_dir"

# Builder deps
# Upgrade packages for be able get latest Checkov (pip, setuptools)
# Install colorlog for properly formatted log
RUN apk add --no-cache \
    bash=~5 \
    curl=~8 \
    jq=~1 &&\
    python3 -m pip install --no-cache-dir --upgrade \
        pip==24.2 \
        setuptools==75.2.0 \
        colorlog==6.8.0

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

FROM python:${TAG}

ENV ANSIBLE_COLLECTIONS_PATH="/usr/bin/collections"
ENV ANSIBLE_ROLES_PATH="/usr/bin/roles"

# Install dependencies
RUN apk add --no-cache \
    git=~2 \
    bash=~5 \
    musl-dev=~1 \
    gcc=~12 \
    su-exec=~0.2 \
    openssh-client=~9 \
    curl=~8 \
    jq=~1 \
    perl=~5 && \
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
