# frozen_string_literal: true

Then('the step {string} is active on the step nav') do |nav_step|
  expect_in_person_step_indicator_current_step(t("step_indicator.flows.idv.#{nav_step}"))
end
