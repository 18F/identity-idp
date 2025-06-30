require 'rails_helper'

RSpec.describe AbTests do
  describe '#all' do
    it 'returns all registered A/B tests' do
      expect(AbTests.all.values).to all(be_kind_of(AbTest))
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

  shared_examples 'A/B test using verify_info_step_document_capture_session_uuid discriminator' do
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

        context 'with a verify_info_step_document_capture_session_uuid in their IdV session' do
          let(:user_session) do
            {
              idv: {
                verify_info_step_document_capture_session_uuid: 'a-random-uuid',
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
    end

    context 'when A/B test is disabled and it would otherwise assign a bucket' do
      let(:user) { build(:user) }

      let(:user_session) do
        {
          idv: {
            verify_info_step_document_capture_session_uuid: 'a-random-uuid',
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

  shared_examples 'an A/B test that uses user_uuid as a discriminator' do
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

      it 'does not return a bucket' do
        expect(bucket).to be_nil
      end

      it 'does not write :idv key in user_session' do
        expect { bucket }.not_to change { user_session }
      end

      context 'and user is logged in' do
        let(:user) { build(:user) }

        it 'returns a bucket' do
          expect(bucket).not_to be_nil
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
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_default)
          .and_return('vendor_a')
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_switching_enabled)
          .and_return(true)
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_socure_percent)
          .and_return(50)
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_lexis_nexis_percent)
          .and_return(30)
      }
    end

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_switching_enabled)
          .and_return(false)
      }
    end

    it_behaves_like 'an A/B test that uses user_uuid as a discriminator'
  end

  describe 'DOC_AUTH_SELFIE_VENDOR' do
    let(:ab_test) { :DOC_AUTH_SELFIE_VENDOR }

    let(:enable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_vendor_default)
          .and_return('vendor_a')
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_vendor_switching_enabled)
          .and_return(true)
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_vendor_socure_percent)
          .and_return(50)
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_vendor_lexis_nexis_percent)
          .and_return(30)
      }
    end

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_vendor_switching_enabled)
          .and_return(false)
      }
    end

    it_behaves_like 'an A/B test that uses user_uuid as a discriminator'
  end

  describe 'ACUANT_SDK' do
    let(:ab_test) { :ACUANT_SDK }

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled)
          .and_return(false)
      }
    end

    let(:enable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled)
          .and_return(true)

        allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_percent)
          .and_return(50)
      }
    end

    it_behaves_like 'an A/B test that uses document_capture_session_uuid as a discriminator'
  end

  describe 'RECAPTCHA_SIGN_IN' do
    let(:user) { nil }
    let(:user_session) { {} }

    subject(:bucket) do
      AbTests::RECAPTCHA_SIGN_IN.bucket(
        request: nil,
        service_provider: nil,
        session: nil,
        user:,
        user_session:,
      )
    end

    context 'when A/B test is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:sign_in_recaptcha_percent_tested).and_return(0)
        reload_ab_tests
      end

      context 'when it would otherwise assign a bucket' do
        let(:user) { build(:user) }

        it 'does not return a bucket' do
          expect(bucket).to be_nil
        end
      end
    end

    context 'when A/B test is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:sign_in_recaptcha_percent_tested).and_return(100)
        reload_ab_tests
      end

      context 'with no associated user' do
        let(:user) { nil }

        it 'returns a bucket' do
          expect(bucket).not_to be_nil
        end
      end

      context 'with an associated user' do
        let(:user) { build(:user) }

        it 'returns a bucket' do
          expect(bucket).not_to be_nil
        end

        context 'with user session indicating recaptcha was not performed at sign-in' do
          let(:user_session) { { captcha_validation_performed_at_sign_in: false } }

          it 'does not return a bucket' do
            expect(bucket).to be_nil
          end
        end
      end
    end
  end

  describe 'RECOMMEND_WEBAUTHN_PLATFORM_FOR_SMS_USER' do
    let(:user) { create(:user) }

    subject(:bucket) do
      AbTests::RECOMMEND_WEBAUTHN_PLATFORM_FOR_SMS_USER.bucket(
        request: nil,
        service_provider: nil,
        session: nil,
        user:,
        user_session: nil,
      )
    end

    before do
      allow(IdentityConfig.store).to receive(
        :recommend_webauthn_platform_for_sms_ab_test_account_creation_percent,
      ).and_return(recommend_webauthn_platform_for_sms_ab_test_account_creation_percent)
      allow(IdentityConfig.store).to receive(
        :recommend_webauthn_platform_for_sms_ab_test_authentication_percent,
      ).and_return(recommend_webauthn_platform_for_sms_ab_test_authentication_percent)
      reload_ab_tests
    end

    context 'when A/B test is disabled' do
      let(:recommend_webauthn_platform_for_sms_ab_test_account_creation_percent) { 0 }
      let(:recommend_webauthn_platform_for_sms_ab_test_authentication_percent) { 0 }

      it 'does not return a bucket' do
        expect(bucket).to be_nil
      end
    end

    context 'when A/B test is enabled' do
      let(:recommend_webauthn_platform_for_sms_ab_test_account_creation_percent) { 1 }
      let(:recommend_webauthn_platform_for_sms_ab_test_authentication_percent) { 1 }

      it 'returns a bucket' do
        expect(bucket).not_to be_nil
      end
    end
  end

  describe 'SOCURE_IDV_SHADOW_MODE_FOR_NON_DOCV_USERS' do
    let(:user) { create(:user) }

    subject(:bucket) do
      AbTests::SOCURE_IDV_SHADOW_MODE_FOR_NON_DOCV_USERS.bucket(
        request: nil,
        service_provider: nil,
        session: nil,
        user:,
        user_session: nil,
      )
    end

    before do
      allow(IdentityConfig.store).to receive(
        :socure_idplus_shadow_mode_percent,
      ).and_return(0)
      reload_ab_tests
    end

    context 'when the A/B test is disabled' do
      it 'does not return a bucket' do
        expect(bucket).to be_nil
      end
    end

    context 'when the A/B test is enabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :socure_idplus_shadow_mode_percent,
        ).and_return(100)
        reload_ab_tests
      end

      it 'returns a bucket' do
        expect(bucket).to eq :socure_shadow_mode_for_non_docv_users
      end
    end
  end

  describe 'DESKTOP_FT_UNLOCK_SETUP' do
    let(:user) { nil }
    let(:user_session) { {} }

    subject(:bucket) do
      AbTests::DESKTOP_FT_UNLOCK_SETUP.bucket(
        request: nil,
        service_provider: nil,
        session: nil,
        user:,
        user_session:,
      )
    end

    context 'when A/B test is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:desktop_ft_unlock_setup_option_percent_tested)
          .and_return(0)
        reload_ab_tests
      end

      context 'when it would otherwise assign a bucket' do
        let(:user) { build(:user) }

        it 'does not return a bucket' do
          expect(bucket).to be_nil
        end
      end
    end

    context 'when A/B test is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:desktop_ft_unlock_setup_option_percent_tested)
          .and_return(100)
        reload_ab_tests
      end

      let(:user) { build(:user) }

      it 'returns a bucket' do
        expect(bucket).not_to be_nil
      end
    end
  end

  describe 'DOC_AUTH_PASSPORT' do
    let(:ab_test) { :DOC_AUTH_PASSPORT }

    let(:enable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled)
          .and_return(true)
        allow(IdentityConfig.store).to receive(:doc_auth_passports_percent)
          .and_return(50)
      }
    end

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled)
          .and_return(false)
      }
    end

    it_behaves_like 'an A/B test that uses user_uuid as a discriminator'
  end

  describe 'PROOFING_VENDOR' do
    let(:ab_test) { :PROOFING_VENDOR }

    let(:enable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:idv_resolution_default_vendor)
          .and_return('vendor_a')
        allow(IdentityConfig.store).to receive(:idv_resolution_vendor_switching_enabled)
          .and_return(true)
        allow(IdentityConfig.store).to receive(:idv_resolution_vendor_socure_kyc_percent)
          .and_return(50)
        allow(IdentityConfig.store).to receive(:idv_resolution_vendor_instant_verify_percent)
          .and_return(30)
      }
    end

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:idv_resolution_vendor_switching_enabled)
          .and_return(false)
      }
    end

    it_behaves_like 'A/B test using verify_info_step_document_capture_session_uuid discriminator'
  end
end
