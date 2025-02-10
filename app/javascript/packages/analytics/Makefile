DAP_SHA ?= eebc4d1

digital-analytics-program.js: digital-analytics-program-$(DAP_SHA).js digital-analytics-program.patch
	patch -p1 $^ --output $@

digital-analytics-program-$(DAP_SHA).js:
	curl https://raw.githubusercontent.com/digital-analytics-program/gov-wide-code/$(DAP_SHA)/Universal-Federated-Analytics.js --silent --output $@

clean:
	rm digital-analytics-program-$(DAP_SHA).js digital-analytics-program.js

.PHONY: clean
