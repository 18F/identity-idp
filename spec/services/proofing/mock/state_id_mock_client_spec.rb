require 'rails_helper'

RSpec.describe Proofing::Mock::StateIdMockClient do
  expect_mock_proofer_matches_real_proofer(
    mock_proofer_class: Proofing::Mock::StateIdMockClient,
    real_proofer_class: Proofing::Aamva::Proofer,
  )
end

