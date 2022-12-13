require 'rails_helper'

describe OtpPreferenceUpdater do
  subject do
    OtpPreferenceUpdater.new(
      user: build_stubbed(:user, otp_delivery_preference: 'sms'),
      preference: 'sms',
      phone_id: 1,
    )
  end

  describe '#call' do
    context 'with authentication context' do
      context 'when otp_delivery_preference is the same as the user otp_delivery_preference' do
        it 'does not update the user' do
          user = create(:user, email: 'test1@test.com')
          phone = create(
            :phone_configuration,
            user: user,
            phone: '+1 111 111 1111',
            delivery_preference: 'sms',
          )
          updater = OtpPreferenceUpdater.new(user: user, preference: 'sms', phone_id: phone.id)
          expect(UpdateUser).to_not receive(:new)
          updater.call
        end
      end

      context 'when otp_delivery_preference is different from the user otp_delivery_preference' do
        it 'updates the user' do
          user = build_stubbed(:user, :with_phone, otp_delivery_preference: 'voice')
          updater = OtpPreferenceUpdater.new(
            user: user,
            preference: 'sms',
            phone_id: 1,
          )
          attributes = { otp_delivery_preference: 'sms',
                         otp_make_default_number: nil,
                         phone_id: 1 }

          updated_user = instance_double(UpdateUser)
          allow(UpdateUser).to receive(:new).
            with(user: user, attributes: attributes).and_return(updated_user)

          expect(updated_user).to receive(:call)

          updater.call
        end
      end
    end

    context 'when user is nil' do
      it 'does not update the user' do
        updater = OtpPreferenceUpdater.new(
          user: nil,
          preference: 'sms',
          phone_id: 1,
        )

        expect(UpdateUser).to_not receive(:new)

        updater.call
      end
    end
  end
end
