@id-ipp
Feature: ID-IPP Flow

  Scenario: User is able to compelte scheduling an in-person enrollment
    Given a user is logged in
    And the user begins in-person proofing
    And the user completes the prepared step
    And the user selects a post office
    And the user submits a state id
    And the user submits an ssn
    And the user verifies their information
    When I run cucumber
    Then this should pass

