require 'rails_helper'

describe RequestPasswordReset do
  describe '#perform' do
    context 'when the user is not found' do
      it 'sends the account does not exist email' do
        email = 'nonexistent@example.com'

        mailer = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
        allow(UserMailer).to receive(:account_does_not_exist).
          with(email, 'request_id').and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        RequestPasswordReset.new(email, 'request_id').perform
      end
    end

    context 'when the user is an admin' do
      it 'does not send any emails, to prevent password recovery via email for privileged users' do
        user = build_stubbed(:user, :admin)

        allow(User).to receive(:find_with_email).with(user.email).and_return(user)

        expect(user).to_not receive(:send_reset_password_instructions)

        RequestPasswordReset.new(user.email).perform
      end
    end

    context 'when the user is a tech support person' do
      it 'does not send any emails, to prevent password recovery via email for privileged users' do
        user = build_stubbed(:user, :tech_support)

        allow(User).to receive(:find_with_email).with(user.email).and_return(user)

        expect(user).to_not receive(:send_reset_password_instructions)

        RequestPasswordReset.new(user.email).perform
      end
    end

    context 'when the user is found, not privileged, and confirmed' do
      it 'sends password reset instructions' do
        user = build_stubbed(:user)

        allow(User).to receive(:find_with_email).with(user.email).and_return(user)

        expect(user).to receive(:send_reset_password_instructions)

        RequestPasswordReset.new(user.email).perform
      end
    end

    context 'when the user is found, not privileged, and not yet confirmed' do
      it 'sends password reset instructions' do
        user = build_stubbed(:user, :unconfirmed)

        allow(User).to receive(:find_with_email).with(user.email).and_return(user)

        expect(user).to receive(:send_reset_password_instructions)

        RequestPasswordReset.new(user.email).perform
      end
    end
  end
end
