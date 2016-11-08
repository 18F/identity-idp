require 'rails_helper'

describe Session do
  let(:session_id) { SecureRandom.uuid }
  let(:identity) { build(:identity) }
  subject { Session.new(identity: identity) }

  describe 'Associations' do
    it { is_expected.to belong_to(:identity) }

    it { is_expected.to validate_presence_of(:session_id) }
  end
end
