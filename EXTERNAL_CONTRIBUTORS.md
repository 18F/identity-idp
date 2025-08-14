## External Contributor Guidelines

Login.gov is the public's one account for government. We believe in transparency in government, which includes having an open source repo that invites community contributions. However, Login.gov is in active development, and we have to be realistic about the types of contributions we are able to accept and review in a timely fashion.

This page outlines our extra guidelines for external contributors, but you will stil be beholden to our [CONTRIBUTING](CONTRIBUTING.md) policy. Make sure you have read through and understood those requirements.
 
In order to ensure we can get to your contributions in an effective and efficient way, please adhere to the following guidelines.

There are three primary ways to help:
- Reporting bugs
- Submitting feature requests
- Submitting code

### License
All contributions to this project will be released under the CC0 dedication. By submitting a pull request, or filing a bug, issue, or feature-request you are agreeing to comply with this waiver of copyright interest. Details can be found in our [LICENSE](LICENSE.md).

### Reporting

You may report a bug or submit a feature request by:
- [Submitting a ticket](https://zendesk.login.gov/) at the Login.gov Partner help center.
- [Creating an issue](https://github.com/18F/identity-idp/issues) in our GitHub repo

#### Bug reports

Please include: 
A detailed report of the bug, including:
- Reproduction steps,
- Expected behavior,
- Current behavior, and; 
- Any other relevant information, such as browser type, or mobile vs desktop. 


#### Feature requests

Please include:
- The requesting agency or team,
- The problem that you would like solved,
- Context around the need,

### Submitting code

#### General process   

- Fork this repository
- Make changes in your own fork
- Submit a pull request

For security reasons, external contributions will not trigger our CI/CD pipelines. If a change is reviewed as safe, and approved, a member of the Login.gov engineering team will run the pipeline before the change can be merged.

#### Considerations before working on a code change

##### Bug Fixes

Before working on any code, please submit a bug report and allow us to acknowledge it. If it's a known issue to us, we may already be working on a fix. We wouldn't want you to waste your time if a fix is in progress!

##### Features
We do not accept PRs for new features (or that extend current features) from external contributors. 

We have a specific internal process for researching, designing and developing features. As we are a shared service that operates government-wide, we need to evaluate whether a feature is a good fit for all our partners before we can consider building it out. 

If you'd like to submit a feature request for consideration, please follow the steps outlined above.

### PR Requirements

Our engineering capacity does not allow for much time for code review of external contributions. For this reason, we can only accept small, concise code changes that don't conflict with work we have in-flight.

We will not be able to review a change until the following steps are met:

- There are associated unit tests that validate the change,
- There is evidence of manual accessibility testing for any client-side code,
- All specs are passing, and;
- The code matches existing patterns.
