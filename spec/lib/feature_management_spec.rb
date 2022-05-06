require 'rails_helper'

describe 'FeatureManagement', type: :feature do
  describe '#prefill_otp_codes?' do
    context 'when SMS sending is disabled' do
      before { allow(FeatureManagement).to receive(:telephony_test_adapter?).and_return(true) }

      it 'returns true in development mode' do
        allow(Rails.env).to receive(:development?).and_return(true)

        expect(FeatureManagement.prefill_otp_codes?).to eq(true)
      end

      it 'returns false in non-development mode' do
        allow(Rails.env).to receive(:development?).and_return(false)

        expect(FeatureManagement.prefill_otp_codes?).to eq(false)
      end
    end

    context 'in production servers' do
      before do
        allow(FeatureManagement).to receive(:telephony_test_adapter?).and_return(true)
        allow(Rails.env).to receive(:production?).and_return(true)
      end

      context 'when the server is in production' do
        before do
          allow(Identity::Hostdata).to receive(:domain).and_return('login.gov')
        end

        it 'does not prefill codes' do
          expect(FeatureManagement.prefill_otp_codes?).to eq(false)
        end
      end

      context 'when the server is in sandbox' do
        before do
          allow(Identity::Hostdata).to receive(:domain).and_return('identitysandbox.gov')
        end

        it 'prefills codes' do
          expect(FeatureManagement.prefill_otp_codes?).to eq(true)
        end
      end
    end

    context 'when SMS sending is enabled' do
      before { allow(FeatureManagement).to receive(:telephony_test_adapter?).and_return(false) }

      it 'returns false in development mode' do
        allow(Rails.env).to receive(:development?).and_return(true)

        expect(FeatureManagement.prefill_otp_codes?).to eq(false)
      end

      it 'returns false in non-development mode' do
        allow(Rails.env).to receive(:development?).and_return(false)

        expect(FeatureManagement.prefill_otp_codes?).to eq(false)
      end

      it 'returns false in production mode when server is pt' do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(IdentityConfig.store).to receive(:domain_name).and_return('idp.pt.login.gov')

        expect(FeatureManagement.prefill_otp_codes?).to eq(false)
      end
    end
  end

  describe '#use_kms?' do
    context 'when enabled' do
      before do
        allow(IdentityConfig.store).to receive(:use_kms).and_return(true)
      end

      it 'enables the feature' do
        expect(FeatureManagement.use_kms?).to eq(true)
      end
    end
  end

  describe '#use_dashboard_service_providers?' do
    context 'when enabled' do
      before do
        allow(IdentityConfig.store).to receive(:use_dashboard_service_providers).and_return(true)
      end

      it 'enables the feature' do
        expect(FeatureManagement.use_dashboard_service_providers?).to eq(true)
      end
    end

    context 'when disabled' do
      before do
        allow(IdentityConfig.store).to receive(:use_dashboard_service_providers).and_return(false)
      end

      it 'disables the feature' do
        expect(FeatureManagement.use_dashboard_service_providers?).to eq(false)
      end
    end
  end

  describe '#reveal_gpo_code?' do
    context 'server domain name is dev, qa, or int' do
      it 'returns true' do
        %w[idp.dev.login.gov idp.int.login.gov idp.qa.login.gov].each do |domain|
          allow(IdentityConfig.store).to receive(:domain_name).and_return(domain)

          expect(FeatureManagement.reveal_gpo_code?).to eq(true)
        end
      end
    end

    context 'Rails env is development' do
      it 'returns true' do
        allow(Rails.env).to receive(:development?).and_return(true)

        expect(FeatureManagement.reveal_gpo_code?).to eq(true)
      end
    end

    context 'Rails env is not development and server is not dev, qa, or int' do
      it 'returns false' do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(IdentityConfig.store).to receive(:domain_name).and_return('foo.login.gov')

        expect(FeatureManagement.reveal_gpo_code?).to eq(false)
      end
    end
  end

  describe '.show_demo_banner?' do
    subject(:show_demo_banner?) { FeatureManagement.show_demo_banner? }

    context 'in local development' do
      it 'is false' do
        expect(show_demo_banner?).to be_falsey
      end
    end

    context 'in a deployed environment' do
      before { expect(Identity::Hostdata).to receive(:in_datacenter?).and_return(true) }

      context 'in a non-prod env' do
        before { expect(Identity::Hostdata).to receive(:env).and_return('staging') }

        it 'is true' do
          expect(show_demo_banner?).to be_truthy
        end
      end

      context 'in production' do
        before { expect(Identity::Hostdata).to receive(:env).and_return('prod') }

        it 'is false' do
          expect(show_demo_banner?).to be_falsey
        end
      end
    end
  end

  describe '.show_no_pii_banner?' do
    subject(:show_no_pii_banner?) { FeatureManagement.show_no_pii_banner? }

    context 'in local development' do
      it 'is false' do
        expect(show_no_pii_banner?).to eq(false)
      end
    end

    context 'in a deployed environment' do
      before { expect(Identity::Hostdata).to receive(:in_datacenter?).and_return(true) }

      context 'in the sandbox domain' do
        before { expect(Identity::Hostdata).to receive(:domain).and_return('identitysandbox.gov') }

        it 'is true' do
          expect(show_no_pii_banner?).to eq(true)
        end
      end

      context 'in the prod domain' do
        before { expect(Identity::Hostdata).to receive(:domain).and_return('login.gov') }

        it 'is false' do
          expect(show_no_pii_banner?).to eq(false)
        end
      end
    end
  end

  describe 'piv/cac feature' do
    describe '#identity_pki_disabled?' do
      context 'when enabled' do
        before(:each) do
          allow(IdentityConfig.store).to receive(:identity_pki_disabled) { true }
        end

        it 'has the feature disabled' do
          expect(FeatureManagement.identity_pki_disabled?).to be_truthy
        end
      end

      context 'when disabled' do
        before(:each) do
          allow(IdentityConfig.store).to receive(:identity_pki_disabled) { false }
        end

        it 'has the feature disabled' do
          expect(FeatureManagement.identity_pki_disabled?).to be_falsey
        end
      end
    end

    describe '#development_and_identity_pki_disabled?' do
      context 'in development environment' do
        before(:each) do
          allow(Rails.env).to receive(:development?).and_return(true)
        end

        context 'identity_pki disabled' do
          it 'returns true' do
            allow(IdentityConfig.store).to receive(:identity_pki_disabled) { true }
            expect(FeatureManagement.development_and_identity_pki_disabled?).to be_truthy
          end
        end

        context 'identity_pki not disabled' do
          it 'returns false' do
            allow(IdentityConfig.store).to receive(:identity_pki_disabled) { false }
            expect(FeatureManagement.development_and_identity_pki_disabled?).to be_falsey
          end
        end
      end

      context 'in production environment' do
        before(:each) do
          allow(Rails.env).to receive(:production?).and_return(true)
          allow(Rails.env).to receive(:development?).and_return(false)
        end

        context 'identity_pki disabled' do
          it 'returns false' do
            allow(IdentityConfig.store).to receive(:identity_pki_disabled) { true }
            expect(FeatureManagement.development_and_identity_pki_disabled?).to be_falsey
          end
        end

        context 'identity_pki not disabled' do
          it 'returns false' do
            allow(IdentityConfig.store).to receive(:identity_pki_disabled) { false }
            expect(FeatureManagement.development_and_identity_pki_disabled?).to be_falsey
          end
        end
      end
    end
  end

  describe '#disallow_all_web_crawlers?' do
    it 'returns true when IdentityConfig setting is true' do
      allow(IdentityConfig.store).to receive(:disallow_all_web_crawlers) { true }

      expect(FeatureManagement.disallow_all_web_crawlers?).to eq(true)
    end

    it 'returns false when IdentityConfig setting is false' do
      allow(IdentityConfig.store).to receive(:disallow_all_web_crawlers) { false }

      expect(FeatureManagement.disallow_all_web_crawlers?).to eq(false)
    end
  end

  describe '#identity_pki_local_dev?' do
    context 'when in development mode' do
      before(:each) do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'returns true when IdentityConfig setting is true' do
        allow(IdentityConfig.store).to receive(:identity_pki_local_dev) { true }

        expect(FeatureManagement.identity_pki_local_dev?).to eq(true)
      end

      it 'returns false when IdentityConfig setting is false' do
        allow(IdentityConfig.store).to receive(:identity_pki_local_dev) { false }

        expect(FeatureManagement.identity_pki_local_dev?).to eq(false)
      end
    end

    context 'when in non-development mode' do
      before(:each) do
        allow(Rails.env).to receive(:development?).and_return(false)
      end

      it 'returns false when IdentityConfig setting is true' do
        allow(IdentityConfig.store).to receive(:identity_pki_local_dev) { true }

        expect(FeatureManagement.identity_pki_local_dev?).to eq(false)
      end

      it 'returns false when IdentityConfig setting is false' do
        allow(IdentityConfig.store).to receive(:identity_pki_local_dev) { false }

        expect(FeatureManagement.identity_pki_local_dev?).to eq(false)
      end
    end
  end

  describe '#document_capture_async_uploads_enabled?' do
    it 'returns true when IdentityConfig presigned S3 URL setting is true' do
      allow(IdentityConfig.store).to receive(:doc_auth_enable_presigned_s3_urls) { true }

      expect(FeatureManagement.document_capture_async_uploads_enabled?).to eq(true)
    end

    it 'returns false when IdentityConfig presigned S3 URL setting is false' do
      allow(IdentityConfig.store).to receive(:doc_auth_enable_presigned_s3_urls) { false }

      expect(FeatureManagement.document_capture_async_uploads_enabled?).to eq(false)
    end
  end

  describe 'log_to_stdout?' do
    context 'outside the test environment' do
      before { allow(Rails.env).to receive(:test?).and_return(false) }

      it 'returns true when enabled' do
        allow(IdentityConfig.store).to receive(:log_to_stdout).and_return(true)

        expect(FeatureManagement.log_to_stdout?).to eq(true)
      end

      it 'returns false when disabled' do
        allow(IdentityConfig.store).to receive(:log_to_stdout).and_return(true)

        expect(FeatureManagement.log_to_stdout?).to eq(true)
      end
    end

    context 'in the test environment' do
      it 'always returns true' do
        allow(IdentityConfig.store).to receive(:log_to_stdout).and_return(true)
        expect(FeatureManagement.log_to_stdout?).to eq(false)

        allow(IdentityConfig.store).to receive(:log_to_stdout).and_return(false)
        expect(FeatureManagement.log_to_stdout?).to eq(false)
      end
    end
  end

  describe 'idv_api_enabled?' do
    context 'with no steps enabled' do
      it 'returns false' do
        allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return([])

        expect(FeatureManagement.idv_api_enabled?).to eq(false)
      end
    end

    context 'with steps enabled' do
      it 'returns true' do
        allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(['example'])

        expect(FeatureManagement.idv_api_enabled?).to eq(true)
      end
    end
  end

  describe '.voip_allowed_phones' do
    before do
      # clear memoization
      FeatureManagement.instance_variable_set(:@voip_allowed_phones, nil)
    end

    it 'normalizes phone numbers and put them in a set' do
      voip_allowed_phones = ['18885551234', '+18888675309']

      expect(IdentityConfig.store).to receive(:voip_allowed_phones).and_return(voip_allowed_phones)
      expect(FeatureManagement.voip_allowed_phones).to eq(Set['+18885551234', '+18888675309'])
    end
  end
end
