# Skincare Routine Tracker
# make test  - Run tests; fails unless coverage >= 90%, mutation score >= 90%
# SKIP_MUTATION=1 make test  - Skip mutation testing (e.g. when muter segfaults)

.PHONY: test coverage

test:
	./scripts/test.sh

coverage:
	./scripts/coverage.sh
