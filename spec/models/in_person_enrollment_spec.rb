require 'rails_helper'

RSpec.describe InPersonEnrollment, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to :user }
    it { is_expected.to belong_to :profile }
  end

  describe 'Status' do
    it { should define_enum_for(:status).
        with_values([:pending, :passed, :failed, :expired, :canceled]) }
  end
end
