require 'rails_helper'

RSpec.describe TwoFactorAuthentication::AuthAppUpdateForm do
  let(:user) { create(:user) }
  let(:original_name) { 'original-name' }
  let(:configuration) { create(:auth_app_configuration, user:, name: original_name) }
  let(:configuration_id) { configuration&.id }
  let(:form) { described_class.new(user:, configuration_id:) }

  describe '#submit' do
    let(:name) { 'new-namae' }
    let(:result) { form.submit(name:) }

    it 'returns a successful result' do
      expect(result.success?).to eq(true)
      expect(result.to_h).to eq(success: true, configuration_id:)
    end

    it 'saves the new name' do
      result

      expect(configuration.reload.name).to eq(name)
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
          configuration_id:,
        )
      end
    end

    context 'with configuration that does not exist' do
      let(:configuration_id) { 'does-not-exist' }

      it 'returns an unsuccessful result' do
        expect(result.success?).to eq(false)
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            configuration_id: { configuration_not_found: true },
          },
          configuration_id:,
        )
      end
    end

    context 'with configuration not belonging to the user' do
      let(:configuration) { create(:auth_app_configuration, name: original_name) }

      it 'returns an unsuccessful result' do
        expect(result.success?).to eq(false)
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            configuration_id: { configuration_not_found: true },
          },
          configuration_id:,
        )
      end

      it 'does not save the new name' do
        expect(configuration).not_to receive(:save)

        result

        expect(configuration.reload.name).to eq(original_name)
      end
    end

    context 'with blank name' do
      let(:name) { '' }

      it 'returns an unsuccessful result' do
        expect(result.success?).to eq(false)
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            name: { blank: true },
          },
          configuration_id:,
        )
      end

      it 'does not save the new name' do
        expect(configuration).not_to receive(:save)

        result

        expect(configuration.reload.name).to eq(original_name)
      end
    end

    context 'with duplicate name' do
      before do
        create(:auth_app_configuration, user:, name:)
      end

      it 'returns an unsuccessful result' do
        expect(result.success?).to eq(false)
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            name: { duplicate: true },
          },
          configuration_id:,
        )
      end

      it 'does not save the new name' do
        expect(configuration).not_to receive(:save)

        result

        expect(configuration.reload.name).to eq(original_name)
      end
    end
  end

  describe '#name' do
    subject(:name) { form.name }

    it 'returns configuration name' do
      expect(name).to eq(configuration.name)
    end
  end

  describe '#configuration' do
    subject(:form_configuration) { form.configuration }

    it 'returns configuration' do
      expect(form_configuration).to eq(configuration)
    end
  end
end
