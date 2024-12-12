@id-ipp
Feature: ID-IPP Flow

  @presentation
  Scenario: User is able to complete scheduling an in-person enrollment
    Given a user is logged in
    And the user begins in-person proofing
    And the user completes the prepared step
    And the user selects a post office
    And the user submits a state id
    And the user submits an ssn
    And the user verifies their information
    And the user submits their phone number for verification
    And the user verifies their phone number
    When the user submits their password
    Then the user is navigated to the personal key page
    And the user has a "pending" in-person enrollment
    And the user has a pending profile
