require 'rails_helper'

RSpec.describe AbTests do
  describe '#all' do
    it 'returns all registered A/B tests' do
      expect(AbTests.all).to match(
        {
          ACUANT_SDK: an_instance_of(AbTest),
          DOC_AUTH_VENDOR: an_instance_of(AbTest),

        },
      )
    end
  end

  describe '#document_capture_session_uuid_discriminator' do
    let(:request) { spy }
    let(:user) { build(:user) }
    let(:service_provider) {}
    let(:session) { {} }
    let(:user_session) { {} }
    let(:service_provider) {}

    subject(:discriminator) do
      AbTests.document_capture_session_uuid_discriminator(
        service_provider:,
        session:,
        user:,
        user_session:,
      )
    end

    context 'when document_capture_session_uuid is present in session' do
      let(:session) do
        {
          document_capture_session_uuid: 'super-random-uuid',
        }
      end
      context 'and user is nil' do
        let(:user) {}
        it 'returns the uuid in session' do
          expect(discriminator).to eql('super-random-uuid')
        end
      end
      context 'and user is not nil' do
        it 'does not return the uuid in session' do
          expect(discriminator).to be_nil
        end
      end
    end

    context 'when document_capture_session_uuid is not present in session' do
      context 'when user is nil' do
        let(:user) {}
        it 'returns nil' do
          expect(discriminator).to be_nil
        end
      end

      context 'when user_session is nil' do
        let(:user_session) {}
        it 'returns nil' do
          expect(discriminator).to be_nil
        end
      end

      context 'when user_session contains an Idv::Session with a doc capture session uuid' do
        let(:user_session) do
          {
            idv: {
              document_capture_session_uuid: 'super-random-uuid',
            },
          }
        end

        it 'returns it' do
          expect(discriminator).to eql('super-random-uuid')
        end
      end
    end
  end
end
