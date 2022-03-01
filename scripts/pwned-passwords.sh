#!/bin/bash

set -eu

usage() {
  cat >&2 << EOM
Usage: ${0} [-nufph]
  -n : -n <number> Number of passwords to store. Default: 3000000
  -u : -u <URL> URL for pwned passwords. Default: 'https://downloads.pwnedpasswords.com/passwords/pwned-passwords-sha1-ordered-by-count-v8.7z'
  -f : -f <file> File to store pwned passwords. Default: pwned-passwords.txt
  -p : Upload to the AWS prod environment
  -h : Display help
EOM
}

check_7z() {
  if ! command -v 7z &> /dev/null; then
    while true; do
      read -p "7z is not installed. Do you wish to install? " yn
      case $yn in
        [Yy]* ) brew install p7zip; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
      esac
    done
  fi
}

pwned_directory="../pwned_passwords"
number_of_passwords=3000000
pwned_url="https://downloads.pwnedpasswords.com/passwords/pwned-passwords-sha1-ordered-by-count-v8.7z"
pwned_7z="${pwned_directory}/pwned-passwords.7z"
pwned_file="${pwned_directory}/pwned-passwords.txt"
aws_prod="false"

download_pwned_passwords() {
  echo "Downloading pwned passwords. This may take awhile ..."
  curl $pwned_url --output $pwned_7z
  7z x $pwned_7z -so | head -n $number_of_passwords | cut -d: -f 1 | sort > $pwned_file
}

post_to_s3() {
  echo "Posting pwned passwords to AWS S3"
  if ! command -v aws-vault &> /dev/null; then
    echo "aws-vault is not installed. Please install via homebrew."
    exit
  fi

  if [ $aws_prod == 'false' ]; then
    aws-vault exec sandbox-power -- \
      aws s3 cp "$pwned_file" "s3://${sandbox_bucket}/common/pwned-passwords.txt"
  fi

  if [ $aws_prod == 'true' ]; then
    aws-vault exec prod-power -- \
      aws s3 cp "$pwned_file" "s3://${prod_bucket}/common/pwned-passwords.txt"
  fi
}

cleanup() {
  echo "Removing pwned passwords 7z file"
  rm $pwned_7z
}

while getopts "hu:f:p" opt; do
  case $opt in
    n ) number_of_passwords=$OPTARG;;
    u ) pwned_url=$OPTARG;;
    f ) pwned_file=$OPTARG;;
    p ) aws_prod='true';;
    h ) usage
    exit 0;;
    * ) usage
    exit 1;;
  esac
done

check_7z
download_pwned_passwords
post_to_s3
cleanup
