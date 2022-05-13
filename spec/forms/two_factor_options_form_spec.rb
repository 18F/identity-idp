require 'rails_helper'

describe TwoFactorOptionsForm do
  let(:user) { build(:user) }
  subject { described_class.new(user) }

  describe '#submit' do
    it 'is successful if the selection is valid' do
      %w[auth_app piv_cac webauthn webauthn_platform].each do |selection|
        result = subject.submit(selection: selection)

        expect(result.success?).to eq true
      end
    end

    it 'is unsuccessful if the selection is invalid for multi mfa' do
      allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
      %w[phone sms voice !!!!].each do |selection|
        result = subject.submit(selection: selection)

        expect(result.success?).to eq false
      end
    end

    it 'is unsuccessful if the selection is invalid' do
      %w[!!!!].each do |selection|
        result = subject.submit(selection: selection)

        expect(result.success?).to eq false
        expect(result.errors).to include :selection
      end
    end

    context "when the selection is different from the user's otp_delivery_preference" do
      it "updates the user's otp_delivery_preference if they have an alternate method selected" do
        user_updater = instance_double(UpdateUser)
        allow(UpdateUser).
          to receive(:new).
          with(
            user: user,
            attributes: { otp_delivery_preference: 'voice' },
          ).
          and_return(user_updater)
        expect(user_updater).to receive(:call)

        subject.submit(selection: ['voice', 'backup_code'])
      end
    end

    context "when the selection is the same as the user's otp_delivery_preference" do
      it "does not update the user's otp_delivery_preference" do
        expect(UpdateUser).to_not receive(:new)

        subject.submit(selection: 'sms')
      end
    end

    context 'when the selection is not voice or sms' do
      it "does not update the user's otp_delivery_preference" do
        expect(UpdateUser).to_not receive(:new)

        subject.submit(selection: 'auth_app')
      end
    end

    context 'when phone is selected' do
      it 'does not submit the phone when selected as the first single option' do
        allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
        %w[phone].each do |selection|
          result = subject.submit(selection: selection)
  
          expect(result.success?).to eq false
        end
      end

      it 'submits the form when phone is selected as an additional method' do
        allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
          %w[auth_app].each do |selection|
            result = subject.submit(selection: selection)
    
            expect(result.success?).to eq true
          end

          %w[phone].each do |selection|
            result = subject.submit(selection: selection)
    
            expect(result.success?).to eq true
        end
      end
    end
  end
end
