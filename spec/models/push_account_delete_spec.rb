require 'rails_helper'

describe PushAccountDelete do
  describe 'Associations' do
    it { is_expected.to validate_presence_of(:created_at) }
    it { is_expected.to validate_presence_of(:agency_id) }
    it { is_expected.to validate_presence_of(:uuid) }
  end
end
