require 'rails_helper'

RSpec.describe Proofing::Mock::AddressMockClient do
  it_behaves_like_mock_proofer(
    mock_proofer_class: Proofing::Mock::AddressMockClient,
    real_proofer_class: Proofing::LexisNexis::PhoneFinder::Proofer,
  )
end
