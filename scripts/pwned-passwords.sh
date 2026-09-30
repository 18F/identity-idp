#!/bin/bash

set -eu

submit_to_s3='false'
pwned_directory="pwned_passwords"
number_of_passwords=3000000
pwned_tmp_directory="tmp/pwned"
pwned_file="${pwned_directory}/pwned_passwords.txt"
aws_env="sandbox"
non_interactive='false'

usage() {
  cat >&2 << EOM
Usage: ${0} [-nfsdpyh]
  -n : -n <number> Number of passwords to store. Default: ${number_of_passwords}
  -f : -f <file> File to store pwned passwords. Default: ${pwned_file}
  -s : Upload to the AWS sandbox environment
  -d : Upload to the AWS dev environment
  -p : Upload to the AWS prod environment
  -y : Non-interactive mode (no prompts). Redownloads and cleans up automatically.
       Uses ambient AWS credentials instead of aws-vault. Intended for CI.
  -h : Display help
EOM
}

download_pwned_passwords() {
  echo "Downloading pwned passwords. This may take awhile ..."
  bundle exec ruby ./lib/pwned_password_downloader.rb
}

check_pwned_download() {
  if [[ -d "$pwned_tmp_directory" ]]; then
    if [[ $non_interactive == "true" ]]; then
      download_pwned_passwords
      return
    fi
    while true; do
      read -p "${pwned_tmp_directory} was found. Do you want to resume / redownload (y/n)?" yn
      case $yn in
          [Yy]* ) download_pwned_passwords; break ;;
          [Nn]* ) break ;;
          * ) echo "Please answer yes or no.";;
      esac
    done
  else
    download_pwned_passwords
  fi
}

process_pwned_download() {
  echo "Processing downloaded password hashes..."
  find $pwned_tmp_directory -type f -exec cat {} + | \
    sort -n -r -t: -k 2 | \
    head -n $number_of_passwords | \
    cut -d: -f 1 | \
    sort > $pwned_file
}

check_passwords() {
  echo "Checking if 'password' is in ${pwned_file}..."
  check="grep -i $(echo -n "password" | openssl dgst -sha1 -binary | xxd -p) -- $pwned_file"
  if [ -z $(eval $check) ]; then
    echo "SHA-1 check for 'password' came up empty. Please redownload the pwned passwords zip"
    exit 1
  else
    echo "Check succeeded!"
  fi
}

check_s3_env() {
  echo "Checking s3 environment variables."
  case $aws_env in
    prod )
      if [[ -z ${prod_bucket:-} ]]; then
        echo "Please assign an environment variable for prod_bucket and run again."
        exit 1
      fi
      ;;
    dev )
      if [[ -z ${dev_bucket:-} ]]; then
        echo "Please assign an environment variable for dev_bucket and run again."
        exit 1
      fi
      ;;
    sandbox )
      if [[ -z ${sandbox_bucket:-} ]]; then
        echo "Please assign an environment variable for sandbox_bucket and run again."
        exit 1
      fi
      ;;
  esac
}

post_to_s3() {
  echo "Posting pwned passwords to AWS S3"

  # In non-interactive (CI) mode, use the ambient AWS credentials directly
  # rather than aws-vault, which is an interactive local-only tool.
  if [[ $non_interactive == "true" ]]; then
    case $aws_env in
      prod )
        echo "Posting to the prod environment."
        aws s3 cp "$pwned_file" "s3://${prod_bucket}/common/pwned_passwords.txt"
        ;;
      dev )
        echo "Posting to the dev environment."
        aws s3 cp "$pwned_file" "s3://${dev_bucket}/common/pwned_passwords.txt"
        ;;
      sandbox )
        echo "Posting to the sandbox environment."
        aws s3 cp "$pwned_file" "s3://${sandbox_bucket}/common/pwned_passwords.txt"
        ;;
    esac
    return
  fi

  if ! command -v aws-vault &> /dev/null; then
    echo "aws-vault is not installed. Please install via homebrew."
    exit
  fi

  case $aws_env in
    sandbox )
      echo "Posting to the sandbox environment."
      aws-vault exec sandbox-power -- \
        aws s3 cp "$pwned_file" "s3://${sandbox_bucket}/common/pwned_passwords.txt"
      ;;
    dev )
      echo "Posting to the dev environment."
      aws-vault exec dev-power -- \
        aws s3 cp "$pwned_file" "s3://${dev_bucket}/common/pwned_passwords.txt"
      ;;
    prod )
      echo "Posting to the prod environment."
      aws-vault exec prod-power -- \
        aws s3 cp "$pwned_file" "s3://${prod_bucket}/common/pwned_passwords.txt"
      ;;
  esac
}

cleanup() {
  if [[ $non_interactive == "true" ]]; then
    echo "Removing pwned passwords hashes directory"
    rm -rf $pwned_tmp_directory
    return
  fi
  read -p "Do you want to remove ${pwned_tmp_directory}? (y/n) " -n 1 -r yn
  if [[ $yn =~ ^[Yy]$ ]]; then
    echo "Removing pwned passwords hashes directory"
    rm -rf $pwned_tmp_directory
  else
    echo "  Goodbye."
    exit 0
  fi
}

while getopts "hn:f:sdpy" opt; do
  case $opt in
    n ) number_of_passwords=$OPTARG;;
    f ) pwned_file=$OPTARG;;
    s ) submit_to_s3='true'; aws_env='sandbox';;
    d ) submit_to_s3='true'; aws_env='dev';;
    p ) submit_to_s3='true'; aws_env='prod';;
    y ) non_interactive='true';;
    h ) usage
    exit 0 ;;
    * ) usage
    exit 1 ;;
  esac
done

check_pwned_download
process_pwned_download
check_passwords
if [[ $submit_to_s3 == "true" ]]; then
  check_s3_env
  post_to_s3
fi
cleanup
