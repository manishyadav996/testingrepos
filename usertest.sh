#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# This script will create authorized key secret if
# we are able to get a value from AWS Secret manager for :
#   <env_name>/shared/authorized_keys/username
#
# where:
#   env_name is extracted from /opt/data/conf/ec2_keys
#
# If no value is found then no file is written.
# -----------------------------------------------------------------------------

help() {
 cat <<END

Usage: check-for-auth-secrets-key.sh [-h] -u <username>
 -h             # Help
 -u             # Username
END
}

error() {
 echo "Error: $*" 1>&2
}

fatal() {
 error "$*"
 exit 1
}

fatal_help() {
 error "$*"
 help
 exit 1
}

get_region() {
  local region=""
  local count=10

  while [ -z "$region" -o $count -gt 0 ]; do
    region=$(ec2metadata --availability-zone | sed s'/.$//')
    let "count--"
    if [ -n "$region" ]; then
      break
    fi
    sleep 1
  done

  echo "$region"
}

region=$(get_region)
if [ -z "$region" ]; then
 echo "Unable to look up region from metadata service "
 exit 1
fi

tags_file="/opt/data/conf/ec2_tags"
if [ ! -f "$tags_file" ]; then
  echo "$tags_file file does not exist!!"
  exit 2
fi

secret_prefix=$(grep -E "^env_name=" "$tags_file" |cut -d'=' -f2)
#admin_side=$(grep -E "^admin_side=" "$tags_file" |cut -d'=' -f2)

if [ -z "$secret_prefix" ]; then
  echo "Neither env_name nor env_type found in $tags_file. Cannot retrieve authorized key."
  # Not an error
fi

change_authkey() {

  auth_key_path="${secret_prefix}/shared/authorized_keys/${user}"
  auth_key_secret=$(/opt/cdtools/secret_retriever.py --raw -r "$region" -s "$auth_key_path" 2> /dev/null |base64 -d )

  if [[ $? -eq 0 ]] && [[ -n "$auth_key_secret" ]]; then
      if grep -Fxq "$auth_key_secret" "$AUTH_FILE"
          then
          echo "Keys already present"
      else
          echo "Found value for secret $auth_key_secret"
          echo "$auth_key_secret" > "$AUTH_FILE"
          chmod 0600 "$AUTH_FILE"
          chown ${user}:${user} "$AUTH_FILE"
      fi
  else
      # No secret? then we should return a non-zero exit code and trigger cloud-error
      fatal "No value found for secret $auth_key_secret"

  fi
}
checks() {

    user=$1
    if id "$user" &>/dev/null; then

        AUTH_DIR="/home/${user}/.ssh"
        AUTH_FILE="$AUTH_DIR/authorized_keys"
        echo "User Found"
        echo "Changing authorized key for $user"
    else
          fatal "User not found"
    fi

    if [ ! -d "$AUTH_DIR" ]; then 
        mkdir "$AUTH_DIR"
        chmod 700 "$AUTH_DIR"

    fi 

    if [ ! -d "$AUTH_FILE" ]; then 
        touch "$AUTH_FILE"
        chmod 600 "$AUTH_FILE"
        chown ${user}:${user} "$AUTH_FILE"
    fi

    change_authkey
}

while getopts ":hu:" opt
do
    case "${opt}" in
        h )
         help
         exit 0
     ;;
        u)
          if [ -z "$2" ] ; then fatal_help "Must enter username" ; fi
          checks "$2" 
     ;;
        *)
          echo "Invalid option -$OPTARG"
     ;;
    esac
done
