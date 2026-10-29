require 'rails_helper'

RSpec.describe DestructiveAccountReset::CreateRequest do
  subject(:requesting_issuer) { 'example-issuer' }
  subject(:create_request) { described_class.new(user, requesting_issuer) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
  end

  describe '#call' do
    context 'when account recovery is enabled' do
      let(:user) { create(:user, :fully_registered) }

      before do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
      end

      it 'rejects legacy creation and sends no notification for eligible users' do
        expect(UserMailer).not_to receive(:with)
        expect(Telephony).not_to receive(:send_account_reset_notice)

        result = create_request.call

        expect(result).not_to be_success
        expect(result.errors).to eq(base: ['account_recovery_required'])
        expect(DestructiveAccountResetRequest.find_by(user: user)).to be_nil
      end

      it 'rejects legacy creation for an active recovery request even with the flag disabled' do
        create(:account_recovery_request, :waiting, user: user)
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)

        expect(create_request.call).not_to be_success
        expect(DestructiveAccountResetRequest.find_by(user: user)).to be_nil
      end

      context 'with an identity-proofed user' do
        let(:user) { create(:user, :proofed) }

        it 'preserves legacy recovery' do
          expect(create_request.call).to be_success
          expect(DestructiveAccountResetRequest.find_by(user: user)).to be_present
        end
      end
    end

    context 'when the user does not have a phone' do
      let(:user) { build(:user) }

      it 'does not include a message_id in the response' do
        response = create_request.call

        expect(response.to_h[:message_id]).to be_blank
      end
    end

    context 'when the user has a phone' do
      let(:user) { build(:user, :with_phone) }

      it 'includes a message_id in the response' do
        response = create_request.call

        expect(response.to_h[:message_id]).to be_present
      end
    end

    context 'when requesting_issuer is passed' do
      let(:user) { build(:user) }

      it 'it stores requesting_issuer' do
        create_request.call
        reset_request = DestructiveAccountResetRequest.find_by(user_id: user.id)

        expect(reset_request.requesting_issuer).to eq requesting_issuer
      end
    end
  end
end
