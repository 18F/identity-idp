require 'rails_helper'

RSpec.describe ForgetAllBrowsers do
  let(:user) { build(:user, remember_device_revoked_at: original_revoked_at) }
  let(:now) { Time.zone.now }
  let(:original_revoked_at) { 30.days.from_now }

  subject(:service) do
    ForgetAllBrowsers.new(user, remember_device_revoked_at: now)
  end

  describe '#call' do
    it 'updates the remember_device_revoked_at' do
      expect { service.call }.to change { user.remember_device_revoked_at.to_i }.
        from(original_revoked_at.to_i).
        to(now.to_i)
    end
  end
end
