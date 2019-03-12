require 'rails_helper'

describe DocCapture do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:request_token) }
    it { is_expected.to validate_presence_of(:requested_at) }
  end
end
