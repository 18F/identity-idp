Changelog
========

Unreleased
-----------

### Improvements/Changes

### Accessibility

### Bug Fixes Users Might Notice

### Behind the Scenes Changes Users Probably Won't Notice
- Add CI check to include changelog message in change requests (#5836)

RC 173 - 2022-01-13
----------------------

### Improvements/Changes
- Authentication: Limit maximum number of phone numbers (LG-5493) (#5779)

### Behind the scenes bug fixes users probably won't notice
- Maintenance: Build IDP Artifacts in GitLab CI (LG-5360) (#5767, #5795)
- Maintenance: Reduce database index size (#5783, #5784)
- Maintenance: Improve Makefile documentation (LG-4635) (#5791, #5792)
- Maintenance: Update Node.js to v14 (#5786)
- Maintenance: Standardize stylesheeting processing pipeline (#5793, #5799)
- Maintenance: Update Ruby code linting (#5794, #5808)
- Maintenance: Improve CSRF handling in test environment (#5796)
- Logging: Log document state/territory in proofing (#5798)
- Authentication: Generate SAML cert for 2022 (#5797, #5800)
- Logging: Improve logging for personal key page (LG-5221) (#5785)
- Maintenance: Remove network request retries to vendors (#5801)
- Maintenance: De-duplicate Rack::Attack rate limiting middleware when rate limiting is enabled (#5803)
- Maintenance: Use shared GitHub sync script in GitLab (#5700)
- Maintenance: Fix Selenium deprecation (#5802)
- Logging: Return false instead of nil when logging invalid backup code (#5804)
- Logging: Log worker metrics to workers.log file (#5809)
