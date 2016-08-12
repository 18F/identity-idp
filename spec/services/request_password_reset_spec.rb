require 'rails_helper'

describe RequestPasswordReset do
  describe '#perform' do
    context 'when the user is not found' do
      it 'does not send any emails' do
        user = instance_double(User, admin?: false, tech?: false)

        expect(user).to_not receive(:send_reset_password_instructions)
        expect(user).to_not receive(:send_confirmation_instructions)

        RequestPasswordReset.new('nonexistent@example.com').perform
      end
    end

    context 'when the user is an admin' do
      it 'does not send any emails' do
        user = instance_double(User, admin?: true, tech?: false)

        allow(User).to receive(:find_by_email).with('admin@example.com').and_return(user)

        expect(user).to_not receive(:send_reset_password_instructions)
        expect(user).to_not receive(:send_confirmation_instructions)

        RequestPasswordReset.new('admin@example.com').perform
      end
    end

    context 'when the user is a tech support person' do
      it 'does not send any emails' do
        user = instance_double(User, admin?: false, tech?: true)

        allow(User).to receive(:find_by_email).with('tech@example.com').and_return(user)

        expect(user).to_not receive(:send_reset_password_instructions)
        expect(user).to_not receive(:send_confirmation_instructions)

        RequestPasswordReset.new('tech@example.com').perform
      end
    end

    context 'when the user is found, not privileged, and confirmed' do
      it 'sends password reset instructions' do
        user = instance_double(User, admin?: false, tech?: false, confirmed?: true)

        allow(User).to receive(:find_by_email).with('user@example.com').and_return(user)

        expect(user).to receive(:send_reset_password_instructions)
        expect(user).to_not receive(:send_confirmation_instructions)

        RequestPasswordReset.new('user@example.com').perform
      end
    end

    context 'when the user is found, not privileged, and not yet confirmed' do
      it 'sends confirmation instructions' do
        user = instance_double(User, admin?: false, tech?: false, confirmed?: false)

        allow(User).to receive(:find_by_email).with('user@example.com').and_return(user)

        expect(user).to_not receive(:send_reset_password_instructions)
        expect(user).to receive(:send_confirmation_instructions)

        RequestPasswordReset.new('user@example.com').perform
      end
    end
  end
end
