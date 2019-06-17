#!/bin/bash
mkdir -p ~/.aws
mkdir -p ~/.saml
cp -n config/.aws/accounts ~/.aws/accounts
cp -n config/.aws/config ~/.aws/config
cp -n config/.saml/credentials ~/.saml/credentials

