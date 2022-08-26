require 'rails_helper'

RSpec.describe Proofing::Mock::AddressMockClient do
  expect_mock_proofer_matches_real_proofer(
    mock_proofer_class: Proofing::Mock::AddressMockClient,
    real_proofer_class: Proofing::LexisNexis::PhoneFinder::Proofer,
  )
end

