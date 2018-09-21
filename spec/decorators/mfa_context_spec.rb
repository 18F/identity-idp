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

      it 'has #selection_presenters defined' do
        expect(mfa.webauthn_configurations).to respond_to(:selection_presenters)
      end

      it 'has no selection presenters' do
        expect(mfa.webauthn_configurations.selection_presenters).to be_empty
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

        it 'has #selection_presenters defined' do
          expect(mfa.webauthn_configurations).to respond_to(:selection_presenters)
        end

        it 'has no selection presenters' do
          expect(mfa.webauthn_configurations.selection_presenters).to be_empty
        end
      end

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
end
