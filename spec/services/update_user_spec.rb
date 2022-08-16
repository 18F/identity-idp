require 'rails_helper'

describe UpdateUser do
  describe '#call' do
    it 'updates the user with the passed in attributes' do
      user = build(:user, otp_delivery_preference: 'sms')
      attributes = { otp_delivery_preference: 'voice' }
      updater = UpdateUser.new(user: user, attributes: attributes)

      updater.call

      expect(user.otp_delivery_preference).to eq 'voice'
      expect(user.voice?).to eq true
    end

    context 'with a phone already configured' do
      let(:user) { create(:user, :with_phone) }

      it 'does not delete the phone configuration' do
        attributes = { phone: nil }
        updater = UpdateUser.new(user: user, attributes: attributes)
        updater.call
        expect(user.phone_configurations.reload).to_not be_empty
      end
    end

    context 'with no phone configured' do
      let(:user) { create(:user) }
      it 'creates a phone configuration' do
        confirmed_at = 1.day.ago.change(usec: 0)
        attributes = {
          otp_delivery_preference: 'voice',
          phone: '+1 222 333-4444',
          phone_confirmed_at: confirmed_at,
        }
        updater = UpdateUser.new(user: user, attributes: attributes)
        updater.call
        phone_configuration = user.phone_configurations.reload.first
        expect(phone_configuration.delivery_preference).to eq 'voice'
        expect(phone_configuration.confirmed_at).to eq confirmed_at
        expect(phone_configuration.phone).to eq '+1 222 333-4444'
      end

      it 'sends a recovery information changed event' do
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryInformationChangedEvent.new(user: user))
        confirmed_at = 1.day.ago.change(usec: 0)
        attributes = {
          otp_delivery_preference: 'voice',
          phone: '+1 222 333-4444',
          phone_confirmed_at: confirmed_at,
        }
        updater = UpdateUser.new(user: user, attributes: attributes)
        updater.call
      end
    end

    context 'when creating a new phone' do
      let(:user) { create(:user) }
      let(:confirmed_at) { 1.day.ago.change(usec: 0) }
      let(:attributes) do
        {
          phone: '+1 222 333-4444',
          phone_confirmed_at: confirmed_at,
          otp_delivery_preference: 'voice',
        }
      end

      context 'when phone is set as default' do
        it 'updates made_default_at timestamp with current date and time' do
          attributes[:otp_make_default_number] = true
          UpdateUser.new(user: user, attributes: attributes).call
          phone_configuration = user.phone_configurations.reload.first
          expect(phone_configuration.made_default_at).to be_within(1.second).of Time.zone.now
        end
      end

      context 'when phone is not set as default' do
        it 'updates made_default_at with nil value' do
          attributes[:otp_make_default_number] = nil
          UpdateUser.new(user: user, attributes: attributes).call
          phone_configuration = user.phone_configurations.reload.first
          expect(phone_configuration.made_default_at).to eq nil
        end
      end

      context 'when phone is not set as default' do
        it 'updates made_default_at with nil value' do
          attributes[:otp_make_default_number] = 'false'
          UpdateUser.new(user: user, attributes: attributes).call
          phone_configuration = user.phone_configurations.reload.first
          expect(phone_configuration.made_default_at).to eq nil
        end
      end
    end

    context 'when updating an existing phone' do
      let(:user) { create(:user) }
      let(:phone_configuration) { create(:phone_configuration, user: user) }
      let(:confirmed_at) { 1.day.ago.change(usec: 0) }
      let(:attributes) do
        {
          phone_id: phone_configuration.id,
          phone: '+1 222 333-4444',
          phone_confirmed_at: confirmed_at,
          otp_delivery_preference: 'sms',
        }
      end

      context 'when phone is set as default' do
        it 'updates made_default_at timestamp with current date and time' do
          attributes[:otp_make_default_number] = true
          UpdateUser.new(user: user, attributes: attributes).call
          phone_configuration.reload
          expect(phone_configuration.made_default_at).to be_within(1.second).of Time.zone.now
        end
      end

      context 'when phone is not set as default' do
        it 'updates made_default_at timestamp with current made_default_at date and time' do
          attributes[:otp_make_default_number] = nil
          original_made_default_at = Time.zone.now - 2.days
          phone_configuration.update(made_default_at: original_made_default_at)
          UpdateUser.new(user: user, attributes: attributes).call
          phone_configuration.reload
          expect(phone_configuration.made_default_at).
            to be_within(1.second).of original_made_default_at
        end
      end

      context 'when phone does not belong to user' do
        it 'does not update the user if the phone does not belong to them' do
          other_phone = create(:phone_configuration)
          attributes[:phone_id] = other_phone.id
          expect do
            UpdateUser.new(user: user, attributes: attributes).call
          end.to_not(change { other_phone.updated_at })
        end
      end
    end
  end
end
