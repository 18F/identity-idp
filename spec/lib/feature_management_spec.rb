require 'rails_helper'

RSpec.describe 'FeatureManagement' do
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
    context 'domain is set to identitysandbox.gov' do
      before do
        allow(Identity::Hostdata).to receive(:domain).and_return('identitysandbox.gov')
      end

      context 'Rails env is development' do
        before do
          allow(Rails.env).to receive(:development?).and_return(true)
          allow(Rails.env).to receive(:production?).and_return(false)
        end
        it 'returns true' do
          expect(FeatureManagement.reveal_gpo_code?).to eq(true)
        end
      end

      context 'Rails env is production' do
        before do
          allow(Rails.env).to receive(:development?).and_return(false)
          allow(Rails.env).to receive(:production?).and_return(true)
        end
        it 'returns true' do
          expect(FeatureManagement.reveal_gpo_code?).to eq(true)
        end
      end
    end

    context 'domain is set to login.gov' do
      context 'Rails env is production' do
        before do
          allow(Rails.env).to receive(:development?).and_return(false)
          allow(Rails.env).to receive(:production?).and_return(true)
        end
        it 'returns false' do
          expect(FeatureManagement.reveal_gpo_code?).to eq(false)
        end
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

  describe '#proofing_device_profiling_collecting_enabled?' do
    it 'returns false for disabled' do
      expect(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:disabled)
      expect(FeatureManagement.proofing_device_profiling_collecting_enabled?).to eq(false)
    end
    it 'returns true for collect_only' do
      expect(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:collect_only)
      expect(FeatureManagement.proofing_device_profiling_collecting_enabled?).to eq(true)
    end
    it 'returns true for enabled' do
      expect(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
      expect(FeatureManagement.proofing_device_profiling_collecting_enabled?).to eq(true)
    end
    it 'raises for invalid value' do
      expect(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:emnabled)
      expect { FeatureManagement.proofing_device_profiling_collecting_enabled? }
        .to raise_error
    end
  end

  describe '#proofing_device_profiling_decisioning_enabled?' do
    it 'returns false for disabled' do
      expect(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:disabled)
      expect(FeatureManagement.proofing_device_profiling_decisioning_enabled?).to eq(false)
    end
    it 'returns false for collect_only' do
      expect(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:collect_only)
      expect(FeatureManagement.proofing_device_profiling_decisioning_enabled?).to eq(false)
    end
    it 'returns true for enabled' do
      expect(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
      expect(FeatureManagement.proofing_device_profiling_decisioning_enabled?).to eq(true)
    end
    it 'raises for invalid value' do
      expect(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:dissabled)
      expect { FeatureManagement.proofing_device_profiling_decisioning_enabled? }
        .to raise_error
    end
  end

  describe '.recaptcha_enabled?' do
    let(:recaptcha_site_key) { '' }
    let(:recaptcha_secret_key) { '' }
    let(:recaptcha_enterprise_api_key) { '' }
    let(:recaptcha_enterprise_project_id) { '' }

    subject(:recaptcha_enabled) { FeatureManagement.recaptcha_enabled? }

    before do
      allow(IdentityConfig.store).to receive(:recaptcha_site_key)
        .and_return(recaptcha_site_key)
      allow(IdentityConfig.store).to receive(:recaptcha_secret_key)
        .and_return(recaptcha_secret_key)
      allow(IdentityConfig.store).to receive(:recaptcha_enterprise_api_key)
        .and_return(recaptcha_enterprise_api_key)
      allow(IdentityConfig.store).to receive(:recaptcha_enterprise_project_id)
        .and_return(recaptcha_enterprise_project_id)
    end

    it { is_expected.to eq(false) }

    context 'with configured recaptcha site key' do
      let(:recaptcha_site_key) { 'key' }

      it { is_expected.to eq(false) }

      context 'with configured recaptcha secret key' do
        let(:recaptcha_secret_key) { 'key' }

        it { is_expected.to eq(true) }
      end

      context 'with configured recaptcha enterprise api key' do
        let(:recaptcha_enterprise_api_key) { 'key' }

        it { is_expected.to eq(false) }

        context 'with configured recaptcha enterprise project id' do
          let(:recaptcha_enterprise_project_id) { 'project-id' }

          it { is_expected.to eq(true) }
        end
      end
    end
  end

  describe '.phone_recaptcha_enabled?' do
    let(:recaptcha_enabled) { false }
    let(:phone_recaptcha_score_threshold) { 0.0 }

    subject(:phone_recaptcha_enabled) { FeatureManagement.phone_recaptcha_enabled? }

    before do
      allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(recaptcha_enabled)
      allow(IdentityConfig.store).to receive(:phone_recaptcha_score_threshold)
        .and_return(phone_recaptcha_score_threshold)
    end

    it { is_expected.to eq(false) }

    context 'with configured default success rate threshold greater than 0' do
      let(:phone_recaptcha_score_threshold) { 1.0 }

      it { is_expected.to eq(false) }

      context 'with recaptcha enabled' do
        let(:recaptcha_enabled) { true }

        it { is_expected.to eq(true) }
      end
    end
  end

  describe '.sign_in_recaptcha_enabled?' do
    let(:recaptcha_enabled) { false }
    let(:sign_in_recaptcha_score_threshold) { 0.0 }

    subject(:sign_in_recaptcha_enabled) { FeatureManagement.sign_in_recaptcha_enabled? }

    before do
      allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(recaptcha_enabled)
      allow(IdentityConfig.store).to receive(:sign_in_recaptcha_score_threshold)
        .and_return(sign_in_recaptcha_score_threshold)
    end

    it { is_expected.to eq(false) }

    context 'with configured default success rate threshold greater than 0' do
      let(:sign_in_recaptcha_score_threshold) { 1.0 }

      it { is_expected.to eq(false) }

      context 'with recaptcha enabled' do
        let(:recaptcha_enabled) { true }

        it { is_expected.to eq(true) }
      end
    end
  end

  describe '.recaptcha_enterprise?' do
    let(:recaptcha_enterprise_api_key) { '' }
    let(:recaptcha_enterprise_project_id) { '' }

    subject(:recaptcha_enterprise) { FeatureManagement.recaptcha_enterprise? }

    before do
      allow(IdentityConfig.store).to receive(:recaptcha_enterprise_api_key)
        .and_return(recaptcha_enterprise_api_key)
      allow(IdentityConfig.store).to receive(:recaptcha_enterprise_project_id)
        .and_return(recaptcha_enterprise_project_id)
    end

    it { expect(recaptcha_enterprise).to eq(false) }

    context 'with configured recaptcha enterprise api key' do
      let(:recaptcha_enterprise_api_key) { 'key' }

      it { expect(recaptcha_enterprise).to eq(false) }

      context 'with configured recaptcha enterprise project id' do
        let(:recaptcha_enterprise_project_id) { 'project_id' }

        it { expect(recaptcha_enterprise).to eq(true) }
      end
    end
  end

  describe '#idv_available?' do
    let(:idv_available) { true }
    let(:vendor_status_lexisnexis_instant_verify) { :operational }
    let(:vendor_status_lexisnexis_trueid) { :operational }

    before do
      allow(IdentityConfig.store).to receive(:idv_available).and_return(idv_available)
      allow(IdentityConfig.store).to receive(:vendor_status_lexisnexis_instant_verify)
        .and_return(vendor_status_lexisnexis_instant_verify)
      allow(IdentityConfig.store).to receive(:vendor_status_lexisnexis_trueid)
        .and_return(vendor_status_lexisnexis_trueid)
    end

    it 'returns true by default' do
      expect(FeatureManagement.idv_available?).to eql(true)
    end

    context 'idv has been disabled using config flag' do
      let(:idv_available) { false }
      it 'returns false' do
        expect(FeatureManagement.idv_available?).to eql(false)
      end
    end

    %w[lexisnexis_instant_verify lexisnexis_trueid].each do |service|
      context "#{service} is in :full_outage" do
        let(:"vendor_status_#{service}") { :full_outage }
        it 'returns false' do
          expect(FeatureManagement.idv_available?).to eql(false)
        end
      end
    end
  end

  describe 'allow_ipp_enrollment_approval?' do
    context 'when IdentityConfig.store.in_person_enrollments_immediate_approval_enabled is true' do
      it 'returns true' do
        allow(IdentityConfig.store).to receive(:in_person_enrollments_immediate_approval_enabled)
          .and_return(true)
        allow(Rails.env).to receive(:production?).and_return(true)

        expect(FeatureManagement.allow_ipp_enrollment_approval?).to eq true
      end
    end

    context 'when IdentityConfig.store.in_person_enrollments_immediate_approval_enabled is false' do
      it 'returns false' do
        allow(IdentityConfig.store).to receive(:in_person_enrollments_immediate_approval_enabled)
          .and_return(false)
        allow(Rails.env).to receive(:production?).and_return(true)

        expect(FeatureManagement.allow_ipp_enrollment_approval?).to eq false
      end
    end
  end
end
