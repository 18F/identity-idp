require 'rails_helper'

describe Users::EmailConfirmationsController do
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
    end
  end
end
