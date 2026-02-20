require 'rails_helper'

RSpec.describe SpReturnLog, type: :model do
  describe 'associations' do
    subject { SpReturnLog.new }

    it { is_expected.to belong_to(:user) }
  end
end
