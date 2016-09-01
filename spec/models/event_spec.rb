require 'rails_helper'

describe Event do
  it { is_expected.to belong_to(:user) }

  describe 'validations' do
    let(:event) { build_stubbed(:event) }

    it { is_expected.to validate_presence_of(:event_type) }

    it 'factory built event is valid' do
      expect(event).to be_valid
    end
  end
end
