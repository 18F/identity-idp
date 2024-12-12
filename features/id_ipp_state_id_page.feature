@id-ipp
Feature: ID-IPP flow: State ID page

  @ui
  Scenario: User is on the state id step
    Given a user is logged in
    When the user reaches the state id page
    Then the step "verify_info" is active on the step nav
    And the state id form is present

  @ui
  Scenario: User submits the state id form having the same address as ID
    Given a user is logged in
    And the user reaches the state id page
    When the user fills out the state id form with:
    | first_name      | Jimmy      |
    | last_name       | Testington |
    | birth_month     | 6          |
    | birth_day       | 24         |
    | birth_year      | 2000       |
    | state_id_number | 123456     |
    | state           | Alaska     |
    | address_1       | qwerty     |
    | address_2       |            |
    | city            | qwertyton  |
    | zipcode         | 12345      |
    | same_as_address | true       |
    And the user submits the form
    Then the user is navigated to the ssn page
