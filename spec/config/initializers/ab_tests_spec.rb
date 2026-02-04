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

  shared_examples 'A/B test using idv_phone_step_document_capture_session_uuid discriminator' do
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

        context 'with a idv_phone_step_document_capture_session_uuid in their IdV session' do
          let(:user_session) do
            {
              idv: {
                idv_phone_step_document_capture_session_uuid: 'a-random-uuid',
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

  shared_examples 'an A/B test with specific bucket configured' do |ab_test, vendor|
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
    let(:user_session) { {} }
    let(:user) { build(:user) }
    let(:namespace) { ab_test.to_s.downcase }

    before do
      allow(IdentityConfig.store).to receive(:"#{namespace}_socure_percent").and_return(0)
      allow(IdentityConfig.store).to receive(:"#{namespace}_lexis_nexis_percent").and_return(0)
      allow(IdentityConfig.store).to receive(:"#{namespace}_lexis_nexis_ddp_percent").and_return(0)
    end

    context "when the #{vendor} vendor is configured to 100 percent" do
      before do
        allow(IdentityConfig.store).to receive(:"#{namespace}_switching_enabled")
          .and_return(true)
        allow(IdentityConfig.store).to receive(:"#{namespace}_#{vendor}_percent")
          .and_return(100)
        reload_ab_tests
      end

      it "returns the #{vendor} bucket" do
        expect(bucket).to eq(vendor.to_sym)
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
          .and_return(25)
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_lexis_nexis_percent)
          .and_return(25)
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_lexis_nexis_ddp_percent)
          .and_return(25)
      }
    end

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_switching_enabled)
          .and_return(false)
      }
    end

    it_behaves_like 'an A/B test that uses user_uuid as a discriminator'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_VENDOR, 'socure'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_VENDOR, 'lexis_nexis'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_VENDOR, 'lexis_nexis_ddp'
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
          .and_return(25)
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_vendor_lexis_nexis_percent)
          .and_return(25)
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_vendor_lexis_nexis_ddp_percent)
          .and_return(25)
      }
    end

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_vendor_switching_enabled)
          .and_return(false)
      }
    end

    it_behaves_like 'an A/B test that uses user_uuid as a discriminator'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_SELFIE_VENDOR, 'socure'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_SELFIE_VENDOR, 'lexis_nexis'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_SELFIE_VENDOR, 'lexis_nexis_ddp'
  end

  describe 'PHONE_FINDER_RDP_VERSION' do
    let(:ab_test) { :PHONE_FINDER_RDP_VERSION }

    let(:enable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:idv_rdp_version_default)
          .and_return('vendor_a')
        allow(IdentityConfig.store).to receive(:idv_rdp_version_switching_enabled)
          .and_return(true)
        allow(IdentityConfig.store).to receive(:idv_rdp_version_v2_percent)
          .and_return(90)
        allow(IdentityConfig.store).to receive(:idv_rdp_version_v3_percent)
          .and_return(10)
      }
    end

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:idv_rdp_version_switching_enabled)
          .and_return(false)
      }
    end

    it_behaves_like 'an A/B test that uses user_uuid as a discriminator'
  end

  describe 'DOC_AUTH_PASSPORT_VENDOR' do
    let(:ab_test) { :DOC_AUTH_PASSPORT_VENDOR }

    let(:enable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_default)
          .and_return('vendor_a')
        allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_switching_enabled)
          .and_return(true)
        allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_socure_percent)
          .and_return(25)
        allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_lexis_nexis_percent)
          .and_return(25)
        allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_lexis_nexis_ddp_percent)
          .and_return(25)
      }
    end

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_switching_enabled)
          .and_return(false)
      }
    end

    it_behaves_like 'an A/B test that uses user_uuid as a discriminator'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_PASSPORT_VENDOR, 'socure'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_PASSPORT_VENDOR, 'lexis_nexis'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_PASSPORT_VENDOR, 'lexis_nexis_ddp'
  end

  describe 'DOC_AUTH_PASSPORT_SELFIE_VENDOR' do
    let(:ab_test) { :DOC_AUTH_PASSPORT_SELFIE_VENDOR }

    let(:enable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_passport_selfie_vendor_default)
          .and_return('vendor_a')
        allow(IdentityConfig.store).to receive(:doc_auth_passport_selfie_vendor_switching_enabled)
          .and_return(true)
        allow(IdentityConfig.store).to receive(:doc_auth_passport_selfie_vendor_socure_percent)
          .and_return(25)
        allow(IdentityConfig.store).to receive(:doc_auth_passport_selfie_vendor_lexis_nexis_percent)
          .and_return(25)
        allow(IdentityConfig.store).to receive(
          :doc_auth_passport_selfie_vendor_lexis_nexis_ddp_percent,
        ).and_return(25)
      }
    end

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:doc_auth_passport_selfie_vendor_switching_enabled)
          .and_return(false)
      }
    end

    it_behaves_like 'an A/B test that uses user_uuid as a discriminator'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_PASSPORT_SELFIE_VENDOR, 'socure'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_PASSPORT_SELFIE_VENDOR, 'lexis_nexis'
    it_behaves_like 'an A/B test with specific bucket configured',
                    :DOC_AUTH_PASSPORT_SELFIE_VENDOR, 'lexis_nexis_ddp'
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

  describe 'HYBRID_MOBILE_TMX_PROCESSED' do
    let(:ab_test) { :HYBRID_MOBILE_TMX_PROCESSED }

    let(:disable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:hybrid_mobile_tmx_processed_percent)
          .and_return(0)
      }
    end

    let(:enable_ab_test) do
      -> {
        allow(IdentityConfig.store).to receive(:hybrid_mobile_tmx_processed_percent)
          .and_return(50)
      }
    end

    it_behaves_like 'an A/B test that uses document_capture_session_uuid as a discriminator'
  end
end
