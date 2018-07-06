require 'rails_helper'

describe TwoFactorAuthentication::PersonalKeyVerifyForm do
  describe '#submit' do
    let(:configuration_manager) do
      user.two_factor_method_manager.configuration_manager(:personal_key)
    end

    context 'when the form is valid' do
      let(:user) { create(:user) }

      let!(:raw_code) { PersonalKeyGenerator.new(user).create }
      let(:form) do
        described_class.new(
          user: user,
          configuration_manager: configuration_manager,
          personal_key: raw_code
        )
      end

      it 'returns FormResponse with success: true' do
        old_key = user.reload.personal_key

        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'personal key' }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.reload.personal_key).to eq old_key
      end
    end

    context 'when the form is invalid' do
      let(:user) { create(:user, :signed_up, personal_key: 'code') }
      let(:form) do
        described_class.new(
          user: user,
          configuration_manager: configuration_manager,
          personal_key: 'foo'
        )
      end

      it 'returns FormResponse with success: false' do
        errors = { personal_key: ['Incorrect personal key'] }

        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'personal key' }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.personal_key).to_not be_nil
        expect(form.personal_key).to be_nil
      end
    end
  end
end
