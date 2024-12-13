@idv-address-step @id-ipp
Feature: In-Person Proofing Address Step

  Scenario: User visits address for the first time
    Given a user is logged in
    And the user has completed IDV steps before the address page
    When the user visits the in-person address page
    Then the page displays the correct heading and button text

  Scenario: User cancels and starts over
    Given a user is logged in
    And the user has completed IDV steps before the address page
    When the user visits the in-person address page
    And the user clicks on the cancel link
    And the user chooses to start over
    Then the user is navigated to the welcome page

  Scenario: User cancels and returns
    Given a user is logged in
    And the user has completed IDV steps before the address page
    When the user visits the in-person address page
    And the user clicks on the cancel link
    And the user chooses to keep going
    Then the user remains on the in-person address page

  Scenario: User submits valid inputs on the address form
    Given a user is logged in
    And the user has completed IDV steps before the address page
    When the user visits the in-person address page
    And the user fills out the address form with valid data
    And the user clicks continue
    Then the user is navigated to the SSN page

  Scenario: User updates their address
    Given a user is logged in
    And the user has completed IDV steps before the address page
    When the user visits the in-person address page
    And the user fills out the address form with valid data
    And the user clicks continue
    Given the user submits an ssn
    And the user clicks on the change address link
    Then the address fields are pre-populated with the user's information

  Scenario: User encounters validation errors
    Given a user is logged in
    And the user has completed IDV steps before the address page
    When the user visits the in-person address page
    And the user fills out the address form with invalid characters
    Then the user sees validation error messages

  Scenario: User validates zip code input
    Given a user is logged in
    And the user has completed IDV steps before the address page
    When the user visits the in-person address page
    And the user submits an invalid zip code
    Then the user sees an error message
    When the user submits a valid zip code
    Then the user is navigated to the SSN page

  Scenario: User selects a state with specific hints
    Given a user is logged in
    And the user has completed IDV steps before the address page
    When the user visits the in-person address page
    And the user selects "Puerto Rico" from the state dropdown
    Then the user sees the address hints
