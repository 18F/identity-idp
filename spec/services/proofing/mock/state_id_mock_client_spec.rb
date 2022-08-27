require 'rails_helper'

RSpec.describe Proofing::Mock::StateIdMockClient do
  it_behaves_like_mock_proofer(
    mock_proofer_class: Proofing::Mock::StateIdMockClient,
    real_proofer_class: Proofing::Aamva::Proofer,
  )
end
