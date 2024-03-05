#!/bin/bash

set -eu

submit_to_s3='false'
pwned_directory="pwned_passwords"
number_of_passwords=3000000
pwned_tmp_directory="tmp/pwned"
pwned_file="${pwned_directory}/pwned_passwords.txt"
aws_prod="false"

usage() {
  cat >&2 << EOM
Usage: ${0} [-nufdph]
  -n : -n <number> Number of passwords to store. Default: ${number_of_passwords}
  -f : -f <file> File to store pwned passwords. Default: ${pwned_file}
  -s : Upload to the AWS sandbox environment
  -p : Upload to the AWS prod environment
  -h : Display help
EOM
}

download_pwned_passwords() {
  echo "Downloading pwned passwords. This may take awhile ..."
  bundle exec ruby ./lib/pwned_password_downloader.rb
}

check_pwned_download() {
  if [[ -d "$pwned_tmp_directory" ]]; then
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
  case $aws_prod in
    true )
      if [[ -z ${prod_bucket:-} ]]; then
        echo "Please assign an environment variable for prod_bucket and run again."
        exit 1
      fi
      ;;
    false )
      if [[ -z ${sandbox_bucket:-} ]]; then
        echo "Please assign an environment variable for sandbox_bucket and run again."
        exit 1
      fi
      ;;
  esac
}

post_to_s3() {
  echo "Posting pwned passwords to AWS S3"
  if ! command -v aws-vault &> /dev/null; then
    echo "aws-vault is not installed. Please install via homebrew."
    exit
  fi

  if [[ $aws_prod == "false" ]]; then
    echo "Posting to the sandbox environment."
    aws-vault exec sandbox-power -- \
      aws s3 cp "$pwned_file" "s3://${sandbox_bucket}/common/pwned-passwords.txt"
  fi

  if [[ $aws_prod == "true" ]]; then
    echo "Posting to the prod environment."
    aws-vault exec prod-power -- \
      aws s3 cp "$pwned_file" "s3://${prod_bucket}/common/pwned-passwords.txt"
  fi
}

cleanup() {
  read -p "Do you want to remove ${pwned_tmp_directory}? (y/n) " -n 1 -r yn
  if [[ $yn =~ ^[Yy]$ ]]; then
    echo "Removing pwned passwords hashes directory"
    rm -rf $pwned_tmp_directory
  else
    echo "  Goodbye."
    exit 0
  fi
}

while getopts "hn:u:f:sp" opt; do
  case $opt in
    n ) number_of_passwords=$OPTARG;;
    f ) pwned_file=$OPTARG;;
    s ) submit_to_s3='true';;
    p ) submit_to_s3='true'; aws_prod='true';;
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
