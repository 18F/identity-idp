require 'rails_helper'

describe UserMfaDecorator do
  describe '#webauthn_configurations' do
    let(:user) { create(:user) }
    let(:mfa) { UserMfaDecorator.new(user) }

    describe '#selection_presenters' do
      it 'is defined' do
        expect(mfa.webauthn_configurations).to respond_to(:selection_presenters)
      end

      context 'with no webauthn_configurations' do
        it 'is empty' do
          expect(mfa.webauthn_configurations.selection_presenters).to be_empty
        end
      end

      context 'with webauthn enabled' do
        before(:each) do
          allow(FeatureManagement).to receive(:webauthn_enabled?).and_return(true)
        end

        context 'with one webauthn_configuration' do
          let(:user) { create(:user, :with_webauthn) }

          it 'has one element' do
            expect(mfa.webauthn_configurations.selection_presenters.count).to eq 1
          end
        end

        context 'with more than one webauthn_configuration' do
          let(:user) do
            record = create(:user)
            create_list(:webauthn_configuration, 3, user: record)
            record.webauthn_configurations.reload
            record
          end

          it 'has one element' do
            expect(mfa.webauthn_configurations.selection_presenters.count).to eq 1
          end
        end
      end
    end
  end
end
