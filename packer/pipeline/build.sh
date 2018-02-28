#!/bin/bash
# This script can be used to clone a repo, build an image with packer and then return its AMI.

set -e

readonly DEFAULT_PACKER_FILE="packer.json"

function print_usage {
  echo
  echo "Usage: build [OPTIONS]"
  echo
  echo "This script can be used to install Vault and its dependencies. This script has been tested with Ubuntu 16.04 and Amazon Linux."
  echo
  echo "Options:"
  echo
  echo -e "  --repo\t\tThe repository to clone from. Required."
  echo -e "  --path\t\tThe relative path of the directory in the repo that contains the packer file. Required"
  echo -e "  --file\t\tThe packer file name. Optional. Default: $DEFAULT_PACKER_FILE."
  echo
  echo "Example:"
  echo
  echo "  build --repo github.com/myrepo --path /packer --file myimage.json"
}

function log {
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local readonly message="$1"
  log "INFO" "$message"
}

function log_warn {
  local readonly message="$1"
  log "WARN" "$message"
}

function log_error {
  local readonly message="$1"
  log "ERROR" "$message"
}

function assert_not_empty {
  local readonly arg_name="$1"
  local readonly arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function has_apt_get {
  [[ -n "$(command -v apt-get)" ]]
}

function install_dependencies {
  log_info "Installing dependencies"

  if $(has_apt_get); then
    sudo apt-get update -y
    sudo apt-get install -y jq
  else
    log_error "Could not find apt-get. Cannot install dependencies on this OS."
    exit 1
  fi
}

function git_clone {
    local readonly repo="$1"

    log_info "Cloning $repo"
    sudo git clone "$repo" "repo"
}

function packer_build {
    local readonly path="$1"
    local readonly file="$2"

    packer build "repo/$path/$file" 
}

function get_ami {
    local readonly path="$1"
    local build_id=`jq '.builds[0].artifact_id' manifest.json | sed -e 's/\(.*\):\(.*\)"\(.*\)/\2/g'`

    jq ".builds[] | select(.packer_run_uuid == ${build_id}) | .artifact_id" manifest.json
}

function main {
  local repo=""
  local path=""
  local file="$DEFAULT_PACKER_FILE"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --repo)
        repo="$2"
        shift
        ;;
      --path)
        path="$2"
        shift
        ;;
      --file)
        file="$2"
        shift
        ;;  
      --help)
        print_usage
        exit
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_not_empty "--repo" "$repo"
  assert_not_empty "--path" "$path"
  assert_not_empty "--file" "$file"

  log_info "Starting Packer build"

  git_clone "$repo"
  packer_build "$path" "$file"
  log_info "Packer build complete!"
  echo get_ami
  return get_ami
}

main "$@"