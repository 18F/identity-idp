require 'rails_helper'

RSpec.describe Users::EmailConfirmationsController do
  describe '#create' do
    describe 'Valid email confirmation tokens' do
      it 'tracks a valid email confirmation token event' do
        user = create(:user)
        new_email = Faker::Internet.safe_email

        expect(PushNotification::HttpPush).to receive(:deliver).once.
          with(PushNotification::EmailChangedEvent.new(
            user: user,
            email: new_email,
          )).ordered

        expect(PushNotification::HttpPush).to receive(:deliver).once.
          with(PushNotification::RecoveryInformationChangedEvent.new(
            user: user,
          )).ordered

        add_email_form = AddUserEmailForm.new
        add_email_form.submit(user, email: new_email)
        email_record = add_email_form.email_address_record(new_email)

        get :create, params: { confirmation_token: email_record.reload.confirmation_token }
      end

      it 'rejects an otherwise valid token for unconfirmed users' do
        user = create(:user, :unconfirmed, email_addresses: [])
        new_email = Faker::Internet.safe_email

        add_email_form = AddUserEmailForm.new
        add_email_form.submit(user, email: new_email)
        email_record = add_email_form.email_address_record(new_email)

        get :create, params: { confirmation_token: email_record.reload.confirmation_token }
        expect(user.email_addresses.confirmed.count).to eq 0
        expect(email_record.reload.confirmed_at).to eq nil
        expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      end

      it 'rejects expired tokens' do
        user = create(:user)
        new_email = Faker::Internet.safe_email

        add_email_form = AddUserEmailForm.new
        add_email_form.submit(user, email: new_email)
        email_record = add_email_form.email_address_record(new_email)

        travel(IdentityConfig.store.add_email_link_valid_for_hours.hours + 1.minute) do
          get :create, params: { confirmation_token: email_record.reload.confirmation_token }
        end

        expect(email_record.reload.confirmed_at).to eq nil
        expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      end

      it 'rejects invalid tokens' do
        get :create, params: { confirmation_token: 'abc' }
        expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      end
    end

    describe 'Invalid email confirmation tokens' do
      it 'rejects invalid parameters' do
        get :create, params: { confirmation_token: { confirmation_token: 'abc' } }
        expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      end
    end
  end
end
