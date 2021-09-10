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


change_password() {  

    ACCOUNT_NAME=$1

    if id "$ACCOUNT_NAME" &>/dev/null; then
        printf "$i":
        echo 'User found'
        echo "Changing password for $ACCOUNT_NAME"
	    ACCOUNT_PASS=$(printf $service_account_passwords | jq -r  '.[] | select(.account_name=='\"$ACCOUNT_NAME\"') | .password_hash')

        #CHNAGE PASSWORD HERE 
        echo "PASSWORD CHANGED : $ACCOUNT_NAME has $ACCOUNT_PASSWORD"
    else
        printf "$i":
        echo "User not found, no password changed"
    fi

}

service_account_passwords_path="${secret_prefix}/shared/service_account_passwords"
service_account_passwords=$(/opt/cdtools/secret_retriever.py -r "$region" -s "$service_account_passwords_path" --raw 2> /dev/null)

if [[ $? -eq 0 ]] && [[ -n "$service_account_passwords" ]]; then
  echo "Found value for secret $service_account_passwords_path"

  for i in $(printf $service_account_passwords | jq -r '.[] | .account_name')
	do 
		echo "function starting for $i"
		CHANGE_PASSWORD $i 
	done

else
  # No secret? then we should return a non-zero exit code and trigger cloud-error
  echo "No value found for secret $service_account_passwords_path"
  exit 1
fi
