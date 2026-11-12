require 'rails_helper'

RSpec.describe Proofing::Resolution::Result do
  subject(:result) { described_class.new(success: true) }

  it 'starts with no resolution attempts' do
    expect(result.resolution_attempts).to eq([])
  end

  it 'does not serialize resolution attempts' do
    result.resolution_attempts << :future_attempt

    expect(result.to_h).not_to have_key(:resolution_attempts)
  end
end
