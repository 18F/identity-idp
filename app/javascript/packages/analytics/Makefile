DAP_SHA ?= 7c14bb3

digital-analytics-program.js: digital-analytics-program-$(DAP_SHA).js digital-analytics-program.patch
	patch -p1 $^ --output $@

clean:
	rm digital-analytics-program-$(DAP_SHA).js digital-analytics-program.js

.PHONY: clean
