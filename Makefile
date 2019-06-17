.PHONY: deps setup test devread prodread

deps:
	brew install bats
	brew install jq
	brew install shellcheck

setup:
	config/setup.sh
test:
	bats test/assume-role.bats

dev = assume-role development read
prod = assume-role production read

devread:
	$(dev)

prodread:
	$(prod)
