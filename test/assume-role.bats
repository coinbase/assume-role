#!/usr/bin/env bats

# jq should be installed for the tests
# Force the stub of aws to make sure we don't accidentally call it
setup() {
  export DEBUG_ASSUME_ROLE="true" # turns on debugging
  export ACCOUNTS_FILE="./test/accounts_file.json"

  # aws stub
  aws() {
    case "$1_$2" in
        configure_get)
            echo "nz-north-1"
            ;;
        iam_get-user)
            echo "aws_username"
            ;;
        iam_list-mfa-devices)
            echo "arn:aws:iam::123456789012:mfa/BobsMFADevice"
            ;;
        sts_get-session-token)
            echo '{
              "Credentials": {
                  "SecretAccessKey": "session_secret_key",
                  "SessionToken": "session_session_token",
                  "Expiration": "2000-10-11T05:12:25Z",
                  "AccessKeyId": "session_key_id"
              }
            } ' | jq -c .
            ;;
        sts_assume-role)
            echo '{
              "Credentials": {
                  "SecretAccessKey": "role_secret_key",
                  "SessionToken": "role_session_token",
                  "Expiration": "2017-10-11T05:12:25Z",
                  "AccessKeyId": "role_key_id"
              }
            }' | jq -c .
            ;;
        *)
          echo "bad stub $1_$2"
          exit 1
    esac
  }
  export -f aws # replace the call to aws with the stub
}

teardown() {
  # This will output the if the test fails
  for i in "${!lines[@]}"
  do
     echo "$i: ${lines[$i]}"
  done

  unset -f aws
  unset DEBUG_ASSUME_ROLE
  unset ACCOUNTS_FILE
}

@test "should work" {
  run ./assume-role dev look_around 123456 us-east-1

  [ "$status" -eq 0 ]

  [ "${lines[0]}" = 'echo "Success! IAM session envars are exported.";' ]
  [ "${lines[1]}" = 'export AWS_REGION="us-east-1";' ]
  [ "${lines[2]}" = 'export AWS_DEFAULT_REGION="us-east-1";' ]
  [ "${lines[3]}" = 'export AWS_ACCESS_KEY_ID="role_key_id";' ]
  [ "${lines[4]}" = 'export AWS_SECRET_ACCESS_KEY="role_secret_key";' ]
  [ "${lines[5]}" = 'export AWS_SESSION_TOKEN="role_session_token";' ]
  [ "${lines[6]}" = 'export AWS_ACCOUNT_ID="123456789012";' ]
  [ "${lines[7]}" = 'export AWS_ACCOUNT_NAME="dev";' ]
  [ "${lines[8]}" = 'export AWS_ACCOUNT_ROLE="look_around";' ]
  [ "${lines[9]}" = 'export AWS_SESSION_ACCESS_KEY_ID="session_key_id";' ]
  [ "${lines[10]}" = 'export AWS_SESSION_SECRET_ACCESS_KEY="session_secret_key";' ]
  [ "${lines[11]}" = 'export AWS_SESSION_SESSION_TOKEN="session_session_token";' ]
  [ "${lines[14]}" = 'export AWS_PROFILE_ASSUME_ROLE="";' ]
  [ "${lines[15]}" = 'AWS_CONFIG_REGION="nz-north-1";' ]
  [ "${lines[16]}" = 'AWS_USERNAME="aws_username";' ]
  [[ "${lines[17]}" == *"--user-name aws_username"* ]] || false
  [ "${lines[18]}" = 'MFA_DEVICE="arn:aws:iam::123456789012:mfa/BobsMFADevice";' ]
  [[ "${lines[19]}" == *"--serial-number arn:aws:iam::123456789012:mfa/BobsMFADevice"* ]] || false
  [[ "${lines[19]}" == *"--token-code 123456"* ]] || false
  [[ "${lines[21]}" == *"--role-arn arn:aws:iam::123456789012:role/look_around"* ]] || false
  [[ "${lines[21]}" == *"--external-id 123456789012"* ]] || false
}

@test "should fail if the account_id is bad" {
  run ./assume-role bad sudo 123456
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'echo "account_id "12345678901212354" is incorrectly formatted AWS account id";' ]
}

@test "should work if the account_id is a string" {
  run ./assume-role string sudo 123456
  [ "$status" -eq 0 ]
  [ "${lines[6]}" = 'export AWS_ACCOUNT_ID="012345678901";' ]
}

@test "should assign the account_id if provided" {
  run ./assume-role 111111111111 sudo 123456
  [ "$status" -eq 0 ]
  [ "${lines[6]}" = 'export AWS_ACCOUNT_ID="111111111111";' ]
}

@test "should fail if style is bad" {
  shellcheck ./assume-role
}
