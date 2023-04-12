require 'rails_helper'

describe TwoFactorOptionsForm do
  let(:user) { build(:user) }
  let(:phishing_resistant_required) { false }
  let(:piv_cac_required) { false }
  subject do
    described_class.new(
      user: user,
      phishing_resistant_required: phishing_resistant_required,
      piv_cac_required: piv_cac_required,
    )
  end

  describe '#submit' do
    let(:submit_phone) { subject.submit(selection: 'phone') }
    let(:enabled_mfa_methods_count) { 0 }
    let(:mfa_selection) { ['sms'] }

    it 'is successful if the selection is valid' do
      %w[auth_app piv_cac webauthn webauthn_platform].each do |selection|
        result = subject.submit(selection: selection)

        expect(result.success?).to eq true
      end
    end

    it 'is unsuccessful if the selection is invalid' do
      %w[!!!!].each do |selection|
        result = subject.submit(selection: selection)

        expect(result.success?).to eq false
        expect(result.errors).to include :selection
      end
    end

    it 'is unsuccessful if the selection is empty' do
      result = subject.submit(selection: [])

      expect(result.success?).to eq false
      expect(result.errors).to include :selection
    end

    it 'is successful if user has existing method and does not select any options' do
      create(:phone_configuration, user: user)

      result = subject.submit(selection: [])
      expect(result.success?).to eq true
    end

    it 'includes analytics hash with a methods count of zero' do
      result = subject.submit(selection: 'piv_cac')

      expect(result.success?).to eq(true)
      expect(result.to_h).to include(enabled_mfa_methods_count: 0)
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

    context 'when a user wants to select phone as their second authentication method' do
      let(:user) { build(:user, :with_authentication_app) }
      let(:enabled_mfa_methods_count) { 1 }
      let(:mfa_selection) { ['phone'] }

      it 'submits the form' do
        expect(submit_phone.success?).to eq true
      end

      it 'includes analytics hash with a method count of one' do
        result = submit_phone

        expect(result.to_h).to include(enabled_mfa_methods_count: 1)
      end
    end

    context 'when a user wants to is required to add piv_cac on sign in' do
      let(:user) { build(:user, :with_authentication_app) }
      let(:enabled_mfa_methods_count) { 1 }
      let(:mfa_selection) { ['phone'] }
      let(:phishing_resistant_required) { true }
      let(:piv_cac_required) { false }

      context 'when user is didnt select an mfa' do
        let(:mfa_selection) { nil }

        it 'does not submits the form' do
          submission = subject.submit(selection: mfa_selection)
          expect(submission.success?).to be_falsey
        end
      end

      context 'when user selects an mfa' do
        it 'submits the form' do
          submission = subject.submit(selection: mfa_selection)
          expect(submission.success?).to be_truthy
        end
      end
    end
  end
end
