require 'rails_helper'

RSpec.describe AbTests do
  describe '#all' do
    it 'returns all registered A/B tests' do
      expect(AbTests.all).to match(
        {
          ACUANT_SDK: an_instance_of(AbTest),
          DOC_AUTH_VENDOR: an_instance_of(AbTest),
          SOCURE: an_instance_of(AbTest),
        },
      )
    end
  end

  shared_examples 'an A/B test that uses document_capture_session_uuid as a discriminator' do
    subject(:bucket) do
      AbTests.all[ab_test].bucket(
        request: nil,
        service_provider: nil,
        session:,
        user:,
        user_session:,
      )
    end

    let(:session) { {} }
    let(:user) { nil }
    let(:user_session) { {} }

    context 'when A/B test is enabled' do
      before do
        enable_ab_test.call
        reload_ab_tests
      end

      context 'and user is logged in' do
        let(:user) { build(:user) }

        context 'and document_capture_session_uuid present' do
          let(:session) { { document_capture_session_uuid: 'a-random-uuid' } }

          it 'returns a bucket' do
            expect(bucket).not_to be_nil
          end
        end

        context 'and document_capture_session_uuid not present' do
          it 'does not return a bucket' do
            expect(bucket).to be_nil
          end
        end

        context 'and the user has a document_capture_session_uuid in their IdV session' do
          let(:user_session) do
            {
              idv: {
                document_capture_session_uuid: 'a-random-uuid',
              },
            }
          end
          it 'returns a bucket' do
            expect(bucket).not_to be_nil
          end
        end
        context 'and the user does not have an Idv::Session' do
          let(:user_session) do
            {}
          end
          it 'does not return a bucket' do
            expect(bucket).to be_nil
          end
          it 'does not write :idv key in user_session' do
            expect { bucket }.not_to change { user_session }
          end
        end
      end

      context 'when user is not logged in' do
        context 'and document_capture_session_uuid present' do
          let(:session) do
            { document_capture_session_uuid: 'a-random-uuid' }
          end
          it 'returns a bucket' do
            expect(bucket).not_to be_nil
          end
        end

        context 'and document_capture_session_uuid not present' do
          it 'does not return a bucket' do
            expect(bucket).to be_nil
          end
        end
      end
    end

    context 'when A/B test is disabled and it would otherwise assign a bucket' do
      let(:user) { build(:user) }
      let(:user_session) do
        {
          idv: {
            document_capture_session_uuid: 'a-random-uuid',
          },
        }
      end

      before do
        disable_ab_test.call
        reload_ab_tests
      end
      it 'does not assign a bucket' do
        expect(bucket).to be_nil
      end
    end
  end

  describe 'DOC_AUTH_VENDOR' do
    let(:ab_test) { :DOC_AUTH_VENDOR }

    let(:enable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_vendor).
          and_return('vendor_a')
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize).
          and_return(true)
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_alternate_vendor).
          and_return('vendor_b')
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent).
          and_return(50)
      }
    end

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize).
          and_return(false)
      }
    end

    it_behaves_like 'an A/B test that uses document_capture_session_uuid as a discriminator'
  end

  describe 'ACUANT_SDK' do
    let(:ab_test) { :ACUANT_SDK }

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled).
          and_return(false)
      }
    end

    let(:enable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled).
          and_return(true)

        allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_percent).
          and_return(50)
      }
    end

    it_behaves_like 'an A/B test that uses document_capture_session_uuid as a discriminator'
  end

  def reload_ab_tests
    AbTests.all.each do |(name, _)|
      AbTests.send(:remove_const, name)
    end
    load('config/initializers/ab_tests.rb')
  end
end
