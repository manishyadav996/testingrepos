#!/usr/bin/env bash


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

tags_file="/usr/local/bin/tag_value.sh"
if [ ! -f "$tags_file" ]; then
  echo "$tags_file file does not exist!!"
  exit 2
fi


secret_prefix=$($tags_file env_name)

# if we didn't find an env_name, look for env_type
if [ -z "$secret_prefix" ]; then
  secret_prefix=$($tags_file env_type)
fi

if [ -z "$secret_prefix" ]; then
  echo "Neither env_name nor env_type found in $tags_file. Cannot retrieve service account passwords."
  # Not an error
fi


change_password()
{
  if id "$i" &>/dev/null; then
    printf "$i":
    echo 'User found'
  else
    printf "$i":
    echo "User not found, no password changed"
  fi
  password=$(echo "$RAW_DATA" | tr '{' '\n' | awk -v user="$i" -F '[":]' '$0~user''{print $10}')
  echo "$i:$password" | chpasswd -e &>/dev/null
  if [[ $? == 0 ]]; then echo "Password Changed"; else echo "Password Change Failed"; fi
}

service_account_passwords_path="${secret_prefix}/shared/service_account_passwords"
service_account_passwords=$(/opt/cdtools/secret_retriever.py -r "$region" -s "$service_account_passwords_path" --raw 2> /dev/null)

if [[ $? -eq 0 ]] && [[ -n "$service_account_passwords" ]]; then
  echo "Found value for secret $service_account_passwords_path"

  RAW_DATA=$(echo "$service_account_passwords" | tr '{' '\n' )
  USER_ACCOUNTS=$(echo "$RAW_DATA" | tr '{' '\n' | awk -F '[":]' '{print $5}')

  if [[ -n $USER_ACCOUNTS ]]; then
    for i in $(printf '%s\n' "$USER_ACCOUNTS")
     do
      change_password
     done
  else
    echo "User Account Not Found"
  fi

else
  # No secret? then we should return a non-zero exit code and trigger cloud-error
  echo "No value found for secret $service_account_passwords_path"
  exit 1
fi
