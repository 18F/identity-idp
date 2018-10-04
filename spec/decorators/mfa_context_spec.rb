require 'rails_helper'

describe MfaContext do
  let(:mfa) { MfaContext.new(user) }

  context 'with no user' do
    let(:user) {}

    describe '#auth_app_configuration' do
      it 'returns a AuthAppConfiguration object' do
        expect(mfa.auth_app_configuration).to be_a AuthAppConfiguration
      end
    end

    describe '#piv_cac_configuration' do
      it 'returns a PivCacConfiguration object' do
        expect(mfa.piv_cac_configuration).to be_a PivCacConfiguration
      end
    end

    describe '#phone_configurations' do
      it 'is empty' do
        expect(mfa.phone_configurations).to be_empty
      end
    end

    describe '#webauthn_configurations' do
      it 'is empty' do
        expect(mfa.webauthn_configurations).to be_empty
      end
    end
  end

  context 'with a user' do
    let(:user) { create(:user) }

    describe '#auth_app_configuration' do
      it 'returns a AuthAppConfiguration object' do
        expect(mfa.auth_app_configuration).to be_a AuthAppConfiguration
      end
    end

    describe '#piv_cac_configuration' do
      it 'returns a PivCacConfiguration object' do
        expect(mfa.piv_cac_configuration).to be_a PivCacConfiguration
      end
    end

    describe '#phone_configurations' do
      it 'mirrors the user relationship' do
        expect(mfa.phone_configurations).to eq user.phone_configurations
      end
    end

    describe '#webauthn_configurations' do
      context 'with no user' do
        let(:user) {}

        it 'is empty' do
          expect(mfa.webauthn_configurations).to be_empty
        end
      end
    end
  end
end
