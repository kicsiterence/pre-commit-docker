# Build orchestration for the pre-commit docker image.
#
# Tool versions are NOT duplicated here — they stay in `docker.args` (which keeps
# its `# renovate:` annotations working). Export them into the environment before
# running bake and the `variable` blocks below pick them up automatically:
#
#   set -a; . ./docker.args; set +a
#   docker buildx bake release        # multi-arch, ready to --push
#   docker buildx bake test           # single-arch, ready to --load for tests
#
variable "IMAGE" { default = "ghcr.io/kicsiterence/pre-commit-docker" }
variable "IMAGE_TAG" { default = "latest" }

# Cache backends default to empty so local builds work without a cache backend.
# CI sets them to `type=gha` / `type=gha,mode=max` via the environment.
variable "CACHE_FROM" { default = "" }
variable "CACHE_TO" { default = "" }

# Sourced from docker.args (no defaults — bake reads them from the environment).
variable "PRE_COMMIT_VERSION" {}
variable "CHECKOV_VERSION" {}
variable "TERRAFORM_VERSION" {}
variable "TERRAFORM_DOCS_VERSION" {}
variable "TERRAGRUNT_VERSION" {}
variable "TFLINT_VERSION" {}
variable "ANSIBLE_VERSION" {}
variable "ANSIBLE_LINT_VERSION" {}

# Settings shared by every target. TARGETOS/TARGETARCH are intentionally absent —
# BuildKit injects them per platform, which is what makes the build multi-arch.
target "_common" {
  context    = "."
  dockerfile = "Dockerfile"
  args = {
    PRE_COMMIT_VERSION     = PRE_COMMIT_VERSION
    CHECKOV_VERSION        = CHECKOV_VERSION
    TERRAFORM_VERSION      = TERRAFORM_VERSION
    TERRAFORM_DOCS_VERSION = TERRAFORM_DOCS_VERSION
    TERRAGRUNT_VERSION     = TERRAGRUNT_VERSION
    TFLINT_VERSION         = TFLINT_VERSION
    ANSIBLE_VERSION        = ANSIBLE_VERSION
    ANSIBLE_LINT_VERSION   = ANSIBLE_LINT_VERSION
  }
  cache-from = CACHE_FROM != "" ? [CACHE_FROM] : []
  cache-to   = CACHE_TO != "" ? [CACHE_TO] : []
}

# Multi-arch image published as a manifest list (`bake release --push`).
target "release" {
  inherits  = ["_common"]
  platforms = ["linux/amd64", "linux/arm64"]
  tags = [
    "${IMAGE}:${IMAGE_TAG}",
    "${IMAGE}:latest",
  ]
}

# Single-arch image for the host platform, loaded into Docker for structure/dive
# tests (`bake test --load`). No explicit platform: it builds the runner's native
# arch (amd64 in CI, arm64 on an Apple-silicon dev machine), so it is loadable.
target "test" {
  inherits = ["_common"]
  tags     = ["${IMAGE}:${IMAGE_TAG}"]
}

group "default" {
  targets = ["release"]
}
