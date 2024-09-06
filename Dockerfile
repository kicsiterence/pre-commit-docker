ARG TAG=3.12.0-alpine3.17@sha256:fc34b07ec97a4f288bc17083d288374a803dd59800399c76b977016c9fe5b8f2
FROM python:${TAG} AS builder

ARG TARGETOS
ARG TARGETARCH

# Install tools
ARG PRE_COMMIT_VERSION=${PRE_COMMIT_VERSION:-latest}
ARG CHECKOV_VERSION=${CHECKOV_VERSION:-false}
ARG TERRAFORM_VERSION=${TERRAFORM_VERSION:-latest}
ARG TERRAFORM_DOCS_VERSION=${TERRAFORM_DOCS_VERSION:-false}
ARG TERRAGRUNT_VERSION=${TERRAGRUNT_VERSION:-false}
ARG TFLINT_VERSION=${TFLINT_VERSION:-false}
ARG ANSIBLE_VERSION=${ANSIBLE_VERSION:-false}
ARG ANSIBLE_LINT_VERSION=${ANSIBLE_LINT_VERSION:-false}

WORKDIR /bin_dir

# Builder deps
# Upgrade packages for be able get latest Checkov (pip, setuptools)
# Install colorlog for properly formatted log
RUN apk add --no-cache \
    curl=~8 \
    jq=~1 && \
    python3 -m pip install --no-cache-dir --upgrade \
        pip==23.3.2 \
        setuptools==69.0.3 \
        colorlog==6.8.0

# Pre-commit
RUN if [ $PRE_COMMIT_VERSION = "latest" ]; then \
        pip3 install --no-cache-dir pre-commit ;\
    else \
        pip3 install --no-cache-dir pre-commit==${PRE_COMMIT_VERSION} ;\
    fi

# Checkov
RUN if [ "$CHECKOV_VERSION" != "false" ]; then \
        apk add --no-cache \
            gcc=~12 \
            libffi-dev=~3 \
            musl-dev=~1; \
        if [ "$CHECKOV_VERSION" = "latest" ]; then \
            pip3 install --no-cache-dir checkov ;\
        else \
            pip3 install --no-cache-dir checkov==${CHECKOV_VERSION}; \
        fi && \
        apk del \
            gcc \
            libffi-dev \
            musl-dev ;\
    fi

# Set SHELL flags for RUN commands to allow -e and pipefail
# Rationale: https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Terraform
RUN set -euxo pipefail && \
    if [ "$TERRAFORM_VERSION" != "false" ]; then \
        if [ "$TERRAFORM_VERSION" = "latest" ]; then \
            TERRAFORM_VERSION="$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r .tag_name)" ;\
        fi && \
        curl -L "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION#*v}/terraform_${TERRAFORM_VERSION#*v}_${TARGETOS}_${TARGETARCH}.zip" > terraform.zip && \
        unzip terraform.zip terraform && \
        rm terraform.zip ;\
    fi

# Terraform-docs
RUN if [ "$TERRAFORM_DOCS_VERSION" != "false" ]; then \
        TERRAFORM_DOCS_RELEASES="https://api.github.com/repos/terraform-docs/terraform-docs/releases" && \
        if [ "$TERRAFORM_DOCS_VERSION" = "latest" ]; then \
            curl -L "$(curl -s ${TERRAFORM_DOCS_RELEASES}/latest | grep -o -E -m 1 "https://.+?-${TARGETOS}-${TARGETARCH}.tar.gz")" > terraform-docs.tgz ;\
        else \
            curl -L "$(curl -s ${TERRAFORM_DOCS_RELEASES} | grep -o -E "https://.+?${TERRAFORM_DOCS_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz")" > terraform-docs.tgz ;\
        fi && \
        tar -xzf terraform-docs.tgz terraform-docs && \
        rm terraform-docs.tgz && \
        chmod +x terraform-docs ;\
    fi

# Terragrunt
RUN if [ "$TERRAGRUNT_VERSION" != "false" ]; then \
        TERRAGRUNT_URL="https://github.com/gruntwork-io/terragrunt/releases/download" && \
        if [ "$TERRAGRUNT_VERSION" = "latest" ]; then \
            curl -L "$(curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest | grep -o -E -m 1 "https://.+?/terragrunt_${TARGETOS}_${TARGETARCH}")" > terragrunt ;\
        else \
            curl -L "${TERRAGRUNT_URL}/${TERRAGRUNT_VERSION}/terragrunt_${TARGETOS}_${TARGETARCH}" > terragrunt ;\
        fi && \
        chmod +x terragrunt ;\
    fi

# TFLint
RUN if [ "$TFLINT_VERSION" != "false" ]; then \
        TFLINT_URL="https://github.com/terraform-linters/tflint/releases/download" && \
        TFLINT_RELEASES="https://api.github.com/repos/terraform-linters/tflint/releases" && \
        if [ "$TFLINT_VERSION" = "latest" ]; then \
            curl -L "$(curl -s "${TFLINT_RELEASES}/latest" | grep -o -E -m 1 "https://.+?_${TARGETOS}_${TARGETARCH}.zip")" > tflint.zip ;\
        else \
            curl -L "${TFLINT_URL}/${TFLINT_VERSION}/tflint_${TARGETOS}_${TARGETARCH}.zip" > tflint.zip ;\
        fi &&\
        unzip tflint.zip && \
        rm tflint.zip ;\
    fi

# Ansible
RUN if [ "$ANSIBLE_VERSION" != "false" ]; then \
        if [ "$ANSIBLE_VERSION" = "latest" ]; then \
            pip3 install --no-cache-dir ansible ;\
        else \
            pip3 install --no-cache-dir ansible=="$ANSIBLE_VERSION"; \
        fi \
    fi

# Ansible-lint
RUN if [ "$ANSIBLE_LINT_VERSION" != "false" ]; then \
        if [ "$ANSIBLE_LINT_VERSION" = "latest" ]; then \
            pip3 install --no-cache-dir ansible-lint &&\
            ANSIBLE_COLLECTIONS_PATH=/bin_dir/collections ansible-galaxy collection install --force ansible.posix community.general community.mysql community.docker amazon.aws; \
            ANSIBLE_ROLES_PATH=/bin_dir/roles ansible-galaxy role install geerlingguy.mysql; \
        else \
            pip3 install --no-cache-dir ansible-lint=="$ANSIBLE_LINT_VERSION" &&\
            ANSIBLE_COLLECTIONS_PATH=/bin_dir/collections ansible-galaxy collection install --force ansible.posix community.general community.mysql community.docker amazon.aws; \
            ANSIBLE_ROLES_PATH=/bin_dir/roles ansible-galaxy role install geerlingguy.mysql; \
        fi \
    fi
# Checking binaries versions and write it to debug file
RUN F="tools_versions_info" && \
    printf "%s\n---\n" "$(pre-commit --version)" >> "$F" && \
    (if [ "$CHECKOV_VERSION"        != "false" ]; then printf "%s\n---\n" "checkov $(checkov --version)" >> "$F";  else printf "%s\n---\n" "checkov SKIPPED" >> "$F"        ; fi) && \
    (if [ "$TERRAFORM_VERSION"      != "false" ]; then printf "%s\n---\n" "$(./terraform --version)" >> "$F";      else printf "%s\n---\n" "terraform SKIPPED" >> "$F"      ; fi) && \
    (if [ "$TERRAFORM_DOCS_VERSION" != "false" ]; then printf "%s\n---\n" "$(./terraform-docs --version)" >> "$F"; else printf "%s\n---\n" "terraform-docs SKIPPED" >> "$F" ; fi) && \
    (if [ "$TERRAGRUNT_VERSION"     != "false" ]; then printf "%s\n---\n" "$(./terragrunt --version)" >> "$F";     else printf "%s\n---\n" "terragrunt SKIPPED" >> "$F"     ; fi) && \
    (if [ "$TFLINT_VERSION"         != "false" ]; then printf "%s\n---\n" "$(./tflint --version)" >> "$F";         else printf "%s\n---\n" "tflint SKIPPED" >> "$F"         ; fi) && \
    (if [ "$ANSIBLE_VERSION"        != "false" ]; then printf "%s\n---\n" "$(ansible --version)" >> "$F";        else printf "%s\n---\n" "ansible SKIPPED" >> "$F"        ; fi) && \
    (if [ "$ANSIBLE_LINT_VERSION"   != "false" ]; then printf "%s\n---\n" "$(ansible-lint --version)" >> "$F";   else printf "%s\n---\n" "ansible-lint SKIPPED" >> "$F"   ; fi) && \
    printf "\n\n" && cat "$F" && printf "\n\n"

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
