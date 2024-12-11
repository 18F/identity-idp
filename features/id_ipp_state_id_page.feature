@id-ipp
Feature: ID-IPP flow: State ID page

  @ui
  Scenario: User is on the state id step
    Given a user is logged in
    When the user reaches the state id page
    Then the step "verify_info" is active on the step nav
    And the state id form is present
