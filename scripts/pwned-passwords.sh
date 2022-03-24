#!/bin/bash

set -eu

submit_to_s3='false'
pwned_directory="pwned_passwords"
number_of_passwords=3000000
pwned_url="https://downloads.pwnedpasswords.com/passwords/pwned-passwords-sha1-ordered-by-count-v8.7z"
pwned_7z="${pwned_directory}/pwned-passwords.7z"
pwned_file="${pwned_directory}/pwned-passwords.txt"
aws_prod="false"

usage() {
  cat >&2 << EOM
Usage: ${0} [-nufdph]
  -n : -n <number> Number of passwords to store. Default: ${number_of_passwords}
  -u : -u <URL> URL for pwned passwords. Default: ${pwned_url}
  -f : -f <file> File to store pwned passwords. Default: ${pwned_file}
  -s : Upload to the AWS sandbox environment
  -p : Upload to the AWS prod environment
  -h : Display help
EOM
}

check_7z() {
  if ! command -v 7z &> /dev/null; then
    while true; do
      read -p "7z is not installed. Do you wish to install (y/n)? " yn
      case $yn in
        [Yy]* ) brew install p7zip; break ;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no." ;;
      esac
    done
  fi
}

download_pwned_passwords() {
  echo "Downloading pwned passwords. This may take awhile ..."
  curl $pwned_url --output $pwned_7z
}

check_pwned_7z() {
  if [[ -f "$pwned_7z" ]]; then
    while true; do
      read -p "${pwned_7z} was found. Do you want to redownload (y/n)?" yn
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

unzip_pwned_passwords() {
  echo "Unzipping ${pwned_7z}."
  7z x $pwned_7z -so | head -n $number_of_passwords | cut -d: -f 1 | sort > $pwned_file
}

check_passwords() {
  echo "Checking if 'password' is in ${pwned_file}..."
  check="grep -i $(echo -n "password" | sha1sum | awk '{print $1}') -- $pwned_file"
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
  read -p "Do you want to remove ${pwned_7z}? (y/n) " -n 1 -r yn
  if [[ $yn =~ ^[Yy]$ ]]; then
    echo "Removing pwned passwords 7z file"
    rm $pwned_7z
  else
    echo "  Goodbye."
    exit 0
  fi
}

while getopts "hn:u:f:sp" opt; do
  case $opt in
    n ) number_of_passwords=$OPTARG;;
    u ) pwned_url=$OPTARG;;
    f ) pwned_file=$OPTARG;;
    s ) submit_to_s3='true';;
    p ) submit_to_s3='true'; aws_prod='true';;
    h ) usage
    exit 0 ;;
    * ) usage
    exit 1 ;;
  esac
done

check_7z
check_pwned_7z
unzip_pwned_passwords
check_passwords
if [[ $submit_to_s3 == "true" ]]; then
  check_s3_env
  post_to_s3
fi
cleanup
