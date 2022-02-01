Changelog
========

Unreleased
-----------

### Improvements/Changes
- Layout: Improve layout margins and typographical consistency across several content pages. (#5857, #5880, #5885)

### Accessibility
- Identity Verification: The Send a Letter "Come back soon" screen has improved grammar and content structure semantics. (#5868)
- Document capture: The image file field label is no longer set to file names so that screen readers do not read the filenames to users. (#5858)

### Bug Fixes Users Might Notice

### Behind the Scenes Changes Users Probably Won't Notice
- Maintenance: Add CI check to include changelog message in change requests (#5836)
- Dependencies: Upgrade the Login.gov Design System to the latest version (#5860)
- Alerting: Manage alerts for duplicate scheduled jobs (#5871)
- Identity Verification: Add more phone number validation to phone confirmation (#5873)
- Dependencies: Update various dependencies (#5877)

RC 175.2 - 2022-01-29
----------------------

### Improvements/Changes
- Authentication: Add the ability to ban users (#5875)

### Behind the Scenes Changes Users Probably Won't Notice
- Identity Verification: Add more phone number validation to phone confirmation (#5873)

RC 175.1 - 2022-01-27
----------------------

### Bug Fixes Users Might Notice
- Bug Fix: Fix a bug on the account screen that caused proofed users who reset their password to see a 500 error. (#5864)

RC 175 - 2022-01-27
----------------------

### Improvements/Changes
- Account management: A new flow was added to reset the personal key from the account screen (#5825)
- Account management: An error message is displayed if a user attempts to add more than 12 emails. (#58320)

### Accessibility
- Dialogs: The text in the "Confirm personal key dialog" is now read by screen readers. (#5806)

### Bug Fixes Users Might Notice
- Content changes: Content was updated to provide clarity to the user. (#5826, #5831, #5833)
- Layout: The "Check Your Email" icon was removed. (#5827)
- Layout: Accordions now use consistent vertical margins. (#5828)
- Layout: Headings are now componentized and consistent across the app. (#5840)
- Design system: "Remember this device" checkboxes now use the Login.gov design system. (#5820)

### Behind the Scenes Changes Users Probably Won't Notice
- Development: Assets are no longer gzipped in the development environment. (#5824)
- Logging: An event is logged when a user sees a warning page during proofing. (#5838)
- Content security policy: 'unsafe-inline' directives were removed from the content security policy. (#5844, #5852)
- Content security policy: URL schemes are now preserved in the content security policy origins. (#5842, #5846)

RC 174 - 2022-01-20
----------------------

### Improvements/Changes
- Identity Verification: Update responsiveness of image capture (#5747, #5830, #5834)
- Rules of Use: Updated Rules of Use timestamp (#5837)
- Multi-factor authentication: Platform authenticators (such as FaceID, Touch ID) are now supported (#5632)

### Bug Fixes Users Might Notice
- Errors: Fixed a few unhandled errors from blank fields (#5823)

### Behind the Scenes Changes Users Probably Won't Notice
- Source code: Update asset compilation pipeline (#5746, #5821)
- Logging: Send worker metrics to workers.log (#5809)
- Logging: Add which screen to image upload events (#5810)
- Source code: Skip generating GZIP assets locally (#5812)
- Source code: Remove redundant CSS class in forms (#5814)
- Source code: Update dependencies (#5818)
- Source code: Add support for TypeScript (#5815)
- Source code: Simplify logic around regenerating personal keys (#5817)
- Source code: Persist Webpack assets manifest between requests (#5805)
- Operations: Add rake task to look up user UUIDs by email address (#5829)

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
