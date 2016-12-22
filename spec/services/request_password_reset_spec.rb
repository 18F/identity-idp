require 'rails_helper'

describe RequestPasswordReset do
  describe '#perform' do
    context 'when the user is not found' do
      it 'does not send any emails' do
        user = build_stubbed(:user)

        expect(user).to_not receive(:send_reset_password_instructions)

        RequestPasswordReset.new('nonexistent@example.com').perform
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
