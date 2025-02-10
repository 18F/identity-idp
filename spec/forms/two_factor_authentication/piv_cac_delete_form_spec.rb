require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PivCacDeleteForm do
  let(:user) { create(:user) }
  let(:configuration) { create(:piv_cac_configuration, user: user) }
  let(:configuration_id) { configuration&.id }
  let(:form) { described_class.new(user: user, configuration_id: configuration_id) }

  describe '#submit' do
    let(:result) { form.submit }

    context 'when the user has another mfa enabled' do
      before do
        create(:phone_configuration, user: user)
      end

      it 'returns a successful result' do
        expect(result.success?).to eq(true)
        expect(result.to_h).to eq(success: true, configuration_id: configuration_id)
      end

      context 'with blank configuration' do
        let(:configuration) { nil }

        it 'returns an unsuccessful result' do
          expect(result.success?).to eq(false)
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              configuration_id: { configuration_not_found: true },
            },
            configuration_id: configuration_id,
          )
        end
      end

      context 'with a non-existent configuration_id' do
        let(:configuration_id) { 'does-not-exist' }

        it 'returns an unsuccessful result' do
          expect(result.success?).to eq(false)
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              configuration_id: { configuration_not_found: true },
            },
            configuration_id: configuration_id,
          )
        end
      end

      context 'with configuration not belonging to the user' do
        let(:configuration) { create(:piv_cac_configuration) }

        it 'returns an unsuccessful result' do
          expect(result.success?).to eq(false)
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              configuration_id: { configuration_not_found: true },
            },
            configuration_id: configuration_id,
          )
        end
      end
    end

    context 'when the user does not have another mfa enabled' do
      let(:user) { create(:user) }

      it 'returns an unsuccessful result' do
        expect(result.success?).to eq(false)
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            configuration_id: { only_method: true },
          },
          configuration_id: configuration_id,
        )
      end
    end
  end

  describe '#configuration' do
    subject(:form_configuration) { form.configuration }

    it 'returns configuration' do
      expect(form_configuration).to eq(configuration)
    end
  end
end
