require 'rails_helper'

describe RememberDeviceRevokedAtMigrator do
  before do
    allow(subject).to receive(:sleep)
  end

  describe '#call' do
    context 'with a user without a phone' do
      it 'skips the user' do
        user = create(:user)

        subject.call

        expect(user.reload.remember_device_revoked_at).to be_nil
      end
    end

    context 'with a user with a phone' do
      it 'copies the phone confirmed_at date to remember_device_revoked_at' do
        confirmed_at = 1.day.ago
        user = create(:user, :with_phone, with: { confirmed_at: confirmed_at })

        subject.call

        expect(user.reload.remember_device_revoked_at.to_i).to eq(confirmed_at.to_i)
      end
    end

    context 'with a user with 2 phones' do
      it 'copies the latest confirmed_at date to remember_device_revoked_at' do
        confirmed_at = 2.days.ago
        user = create(:user, email: 'kevin.gates@example.com')
        create(:phone_configuration, user: user, confirmed_at: confirmed_at)
        create(:phone_configuration, user: user, confirmed_at: confirmed_at - 2.days)

        subject.call

        expect(user.reload.remember_device_revoked_at.to_i).to eq(confirmed_at.to_i)
      end
    end
  end
end
