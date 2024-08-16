DAP_SCRIPT_SHA = 7c14bb3

digital-analytics-program.js: digital-analytics-program.$(DAP_SCRIPT_SHA).js
	patch -p1 digital-analytics-program.$(DAP_SCRIPT_SHA).js digital-analytics-program.patch -o digital-analytics-program.js

digital-analytics-program.$(DAP_SCRIPT_SHA).js:
	curl https://raw.githubusercontent.com/digital-analytics-program/gov-wide-code/$(DAP_SCRIPT_SHA)/Universal-Federated-Analytics.js --silent --output digital-analytics-program.$(DAP_SCRIPT_SHA).js
