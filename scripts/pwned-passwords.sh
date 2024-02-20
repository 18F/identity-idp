#!/bin/bash

set -eu

submit_to_s3='false'
pwned_directory="pwned_passwords"
number_of_passwords=3000000
pwned_file="${pwned_directory}/pwned_passwords.txt"
pwned_file_top_hashes="${pwned_directory}/pwned_passwords_top_hashes.txt"
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
  yarn -s download-pwned-passwords -n $number_of_passwords -o $pwned_file_top_hashes
  sort $pwned_file_top_hashes -o $pwned_file
}

check_pwned_unsorted() {
  if [[ -f "$pwned_file_top_hashes" ]]; then
    while true; do
      read -p "${pwned_file_top_hashes} was found. Do you want to redownload (y/n)?" yn
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

check_passwords() {
  echo "Checking if 'password' is in ${pwned_file}..."
  check="grep -i $(echo -n "password" | sha1sum | awk '{print $1}') -- $pwned_file"
  if [ -z $(eval $check) ]; then
    echo "SHA-1 check for 'password' came up empty. Please redownload the pwned passwords"
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
  read -p "Do you want to remove ${pwned_file_top_hashes}? (y/n) " -n 1 -r yn
  if [[ $yn =~ ^[Yy]$ ]]; then
    echo "Removing pwned passwords 7z file"
    rm $pwned_file_top_hashes
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

check_pwned_unsorted
check_passwords
if [[ $submit_to_s3 == "true" ]]; then
  check_s3_env
  post_to_s3
fi
cleanup
