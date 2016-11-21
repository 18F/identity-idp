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

        fingerprint = Pii::Fingerprinter.fingerprint('admin@example.com')
        allow(User).to receive(:find_by).with(email_fingerprint: fingerprint).and_return(user)

        expect(user).to_not receive(:send_reset_password_instructions)
        expect(user).to_not receive(:send_confirmation_instructions)

        RequestPasswordReset.new('admin@example.com').perform
      end
    end

    context 'when the user is a tech support person' do
      it 'does not send any emails' do
        user = instance_double(User, admin?: false, tech?: true)

        fingerprint = Pii::Fingerprinter.fingerprint('tech@example.com')
        allow(User).to receive(:find_by).with(email_fingerprint: fingerprint).and_return(user)

        expect(user).to_not receive(:send_reset_password_instructions)
        expect(user).to_not receive(:send_confirmation_instructions)

        RequestPasswordReset.new('tech@example.com').perform
      end
    end

    context 'when the user is found, not privileged, and confirmed' do
      it 'sends password reset instructions' do
        user = instance_double(User, admin?: false, tech?: false, confirmed?: true)

        fingerprint = Pii::Fingerprinter.fingerprint('user@example.com')
        allow(User).to receive(:find_by).with(email_fingerprint: fingerprint).and_return(user)

        expect(user).to receive(:send_reset_password_instructions)
        expect(user).to_not receive(:send_confirmation_instructions)

        RequestPasswordReset.new('user@example.com').perform
      end
    end

    context 'when the user is found, not privileged, and not yet confirmed' do
      it 'sends confirmation instructions' do
        user = instance_double(User, admin?: false, tech?: false, confirmed?: false)

        fingerprint = Pii::Fingerprinter.fingerprint('user@example.com')
        allow(User).to receive(:find_by).with(email_fingerprint: fingerprint).and_return(user)

        expect(user).to_not receive(:send_reset_password_instructions)
        expect(user).to receive(:send_confirmation_instructions)

        RequestPasswordReset.new('user@example.com').perform
      end
    end
  end
end
