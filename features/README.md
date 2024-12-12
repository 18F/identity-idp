# Project Cucumber

## Overview

Cucumber is a Behavior Driven Development (BDD) tool that allows for
declarative test procedures using Gherkin. Abstractly, steps written in Gherkin
correlate with Step Definitions that are composed of actual test code. The
impetus for this exploration was an instance on Team Joy where it was helpful
for product and design folks to be able to read tests for a specific scenario.
The Gherkin format allows developers and non-developers alike to more easily
read test flows. The main goal of this exercise was to recreate the test steps
for the In-person Proofing flow using Cucumber.

## Getting Started

Running the tests

```
bundle exec cucumber
```

Running the specific tests

```
bundle exec cucumber <file_name>
```

Running tests based on a tag

```
bundle exec cucumber --tags '@tagname'
```

## Resources:

- https://cucumber.io/docs/guides/overview/
- https://github.com/cucumber/cucumber-ruby
- https://docs.google.com/document/d/1txevuTB-7GjMxoLYpZPSkFZWxrpkqLRIdqZrSfmBKRI
