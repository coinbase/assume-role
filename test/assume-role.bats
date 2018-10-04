#!/usr/bin/env bats

# jq should be installed for the tests
# Force the stub of aws to make sure we don't accidentally call it
setup() {
  export DEBUG_ASSUME_ROLE="true" # turns on debugging
  export ACCOUNTS_FILE="./test/accounts_file.json"
  export SAML_FILE="./test/saml_creds.cfg"
  export SAML_IDP_ASSERTION_URL="https://blah.blob/saml/sso"
  export SAML_IDP_REQUEST_BODY_TEMPLATE='{"service": "aws", "email": "$saml_user", "password": "$saml_password"}'

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
        sts_assume-role-with-saml)
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

  curl() {
    case "$4" in
        $SAML_IDP_ASSERTION_URL)
            echo '{"saml_response": "aGVsbG8="}'
            ;;
        *)
          echo "bad stub $4"
          exit 1
    esac
  }
  export -f aws # replace the call to aws with the stub
  export -f curl # replace the call to curl with the stub
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
  unset SAML_FILE
  unset AWS_ASSUME_ROLE_AUTH_SCHEME
  unset SAML_IDP_REQUEST_BODY_TEMPLATE
  unset SAML_IDP_ASSERTION_URL
  unset SAML_IDP_NAME
}

@test "should work for the bastion auth scheme" {
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
  [ "${lines[15]}" = 'export AWS_PROFILE_ASSUME_ROLE="";' ]
  [ "${lines[17]}" = 'AWS_CONFIG_REGION="nz-north-1";' ]
  [ "${lines[18]}" = 'AWS_USERNAME="aws_username";' ]
  [[ "${lines[19]}" == *"--user-name aws_username"* ]] || false
  [ "${lines[20]}" = 'MFA_DEVICE="arn:aws:iam::123456789012:mfa/BobsMFADevice";' ]
  [[ "${lines[21]}" == *"--serial-number arn:aws:iam::123456789012:mfa/BobsMFADevice"* ]] || false
  [[ "${lines[21]}" == *"--token-code 123456"* ]] || false
  [[ "${lines[23]}" == *"--role-arn arn:aws:iam::123456789012:role/look_around"* ]] || false
  [[ "${lines[23]}" == *"--external-id 123456789012"* ]] || false
}

@test "should work for the SAML auth scheme" {
  export AWS_ASSUME_ROLE_AUTH_SCHEME=saml
  export SAML_IDP_NAME=saml-test-idp
  run ./assume-role dev look_around us-east-1

  [ "$status" -eq 0 ]

  [ "${lines[0]}" = 'echo "Gathering SAML credentials...";' ]
  [ "${lines[1]}" = 'echo "Authenticating with SAML provider...";' ]
  [ "${lines[2]}" = 'echo "Success! IAM session envars are exported.";' ]
  [ "${lines[3]}" = 'export AWS_REGION="us-east-1";' ]
  [ "${lines[4]}" = 'export AWS_DEFAULT_REGION="us-east-1";' ]
  [ "${lines[5]}" = 'export AWS_ACCESS_KEY_ID="role_key_id";' ]
  [ "${lines[6]}" = 'export AWS_SECRET_ACCESS_KEY="role_secret_key";' ]
  [ "${lines[7]}" = 'export AWS_SESSION_TOKEN="role_session_token";' ]
  [ "${lines[8]}" = 'export AWS_ACCOUNT_ID="123456789012";' ]
  [ "${lines[9]}" = 'export AWS_ACCOUNT_NAME="dev";' ]
  [ "${lines[10]}" = 'export AWS_ACCOUNT_ROLE="look_around";' ]
  [ "${lines[19]}" = 'AWS_CONFIG_REGION="nz-north-1";' ]
  [[ "${lines[25]}" == *"--role-arn arn:aws:iam::123456789012:role/look_around"* ]] || false
  [[ "${lines[25]}" == *"--principal-arn arn:aws:iam::123456789012:saml-provider/saml-test-idp"* ]] || false
  [[ "${lines[25]}" = *"--saml-assertion aGVsbG8= --duration-seconds 3600"* ]] || false
}

@test "should fail if the account_id is bad" {
  run ./assume-role bad sudo 123456
  [ "$status" -eq 1 ]
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
