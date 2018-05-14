require 'rails_helper'

describe 'FeatureManagement', type: :feature do
  describe '#prefill_otp_codes?' do
    context 'when SMS sending is disabled' do
      before { allow(FeatureManagement).to receive(:telephony_disabled?).and_return(true) }

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
        allow(FeatureManagement).to receive(:telephony_disabled?).and_return(true)
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Figaro.env).to receive(:domain_name).and_return(domain_name)
      end

      context 'when the server is idp.pt.login.gov' do
        let(:domain_name) { 'idp.pt.login.gov' }

        it 'prefills codes' do
          expect(FeatureManagement.prefill_otp_codes?).to eq(true)
        end
      end

      context 'when the server is idp.dev.login.gov' do
        let(:domain_name) { 'idp.dev.login.gov' }

        it 'prefills codes' do
          expect(FeatureManagement.prefill_otp_codes?).to eq(true)
        end
      end

      context 'when the server is idp.staging.login.gov' do
        let(:domain_name) { 'idp.staging.login.gov' }

        it 'does not prefill codes' do
          expect(FeatureManagement.prefill_otp_codes?).to eq(false)
        end
      end
    end

    context 'when SMS sending is enabled' do
      before { allow(FeatureManagement).to receive(:telephony_disabled?).and_return(false) }

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
        allow(Figaro.env).to receive(:domain_name).and_return('idp.pt.login.gov')

        expect(FeatureManagement.prefill_otp_codes?).to eq(false)
      end
    end
  end

  describe '#enable_i18n_mode?' do
    context 'when enabled' do
      before do
        allow(Figaro.env).to receive(:enable_i18n_mode).and_return('true')
      end

      it 'enables the feature' do
        expect(FeatureManagement.enable_i18n_mode?).to eq(true)
      end
    end

    context 'when disabled' do
      before do
        allow(Figaro.env).to receive(:enable_i18n_mode).and_return('false')
      end

      it 'disables the feature' do
        expect(FeatureManagement.enable_i18n_mode?).to eq(false)
      end
    end
  end

  describe '#use_kms?' do
    context 'when enabled' do
      before do
        allow(Figaro.env).to receive(:use_kms).and_return('true')
      end

      it 'enables the feature' do
        expect(FeatureManagement.use_kms?).to eq(true)
      end
    end
  end

  describe '#use_dashboard_service_providers?' do
    context 'when enabled' do
      before do
        allow(Figaro.env).to receive(:use_dashboard_service_providers).and_return('true')
      end

      it 'enables the feature' do
        expect(FeatureManagement.use_dashboard_service_providers?).to eq(true)
      end
    end

    context 'when disabled' do
      before do
        allow(Figaro.env).to receive(:use_dashboard_service_providers).and_return('false')
      end

      it 'disables the feature' do
        expect(FeatureManagement.use_dashboard_service_providers?).to eq(false)
      end
    end
  end

  describe '#enable_identity_verification?' do
    context 'when enabled' do
      before do
        allow(Figaro.env).to receive(:enable_identity_verification).and_return('true')
      end

      it 'enables the feature' do
        expect(FeatureManagement.enable_identity_verification?).to eq(true)
      end
    end

    context 'when disabled' do
      before do
        allow(Figaro.env).to receive(:enable_identity_verification).and_return('false')
      end

      it 'disables the feature' do
        expect(FeatureManagement.enable_identity_verification?).to eq(false)
      end
    end
  end

  describe '#reveal_usps_code?' do
    context 'server domain name is dev, qa, or int' do
      it 'returns true' do
        %w[idp.dev.login.gov idp.int.login.gov idp.qa.login.gov].each do |domain|
          allow(Figaro.env).to receive(:domain_name).and_return(domain)

          expect(FeatureManagement.reveal_usps_code?).to eq(true)
        end
      end
    end

    context 'Rails env is development' do
      it 'returns true' do
        allow(Rails.env).to receive(:development?).and_return(true)

        expect(FeatureManagement.reveal_usps_code?).to eq(true)
      end
    end

    context 'Rails env is not development and server is not dev, qa, or int' do
      it 'returns false' do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(Figaro.env).to receive(:domain_name).and_return('foo.login.gov')

        expect(FeatureManagement.reveal_usps_code?).to eq(false)
      end
    end
  end

  describe '.no_pii_mode?' do
    let(:proofing_vendor) { :mock }
    let(:enable_identity_verification) { false }

    before do
      allow_any_instance_of(Figaro.env).to receive(:profile_proofing_vendor).
        and_return(proofing_vendor)
      allow(Figaro.env).to receive(:enable_identity_verification).
        and_return(enable_identity_verification.to_json)
    end

    subject(:no_pii_mode?) { FeatureManagement.no_pii_mode? }

    context 'with mock ID-proofing vendors' do
      let(:proofing_vendor) { :mock }

      context 'with identity verification enabled' do
        let(:enable_identity_verification) { true }

        it { expect(no_pii_mode?).to eq(true) }
      end

      context 'with identity verification disabled' do
        let(:enable_identity_verification) { false }

        it { expect(no_pii_mode?).to eq(false) }
      end
    end

    context 'with real ID-proofing vendors' do
      let(:proofing_vendor) { :not_mock }

      context 'with identity verification enabled' do
        let(:enable_identity_verification) { true }

        it { expect(no_pii_mode?).to eq(false) }
      end

      context 'with identity verification disabled' do
        let(:enable_identity_verification) { false }

        it { expect(no_pii_mode?).to eq(false) }
      end
    end
  end

  describe 'piv/cac feature' do
    describe '#piv_cac_enabled?' do
      context 'when enabled' do
        before(:each) do
          allow(Figaro.env).to receive(:piv_cac_enabled) { 'true' }
        end

        it 'has the feature disabled' do
          expect(FeatureManagement.piv_cac_enabled?).to be_truthy
        end
      end

      context 'when disabled' do
        before(:each) do
          allow(Figaro.env).to receive(:piv_cac_enabled) { 'false' }
        end

        it 'has the feature disabled' do
          expect(FeatureManagement.piv_cac_enabled?).to be_falsey
        end
      end
    end

    describe '#identity_pki_disabled?' do
      context 'when enabled' do
        before(:each) do
          allow(Figaro.env).to receive(:identity_pki_disabled) { 'true' }
        end

        it 'has the feature disabled' do
          expect(FeatureManagement.identity_pki_disabled?).to be_truthy
        end
      end

      context 'when disabled' do
        before(:each) do
          allow(Figaro.env).to receive(:identity_pki_disabled) { 'false' }
        end

        it 'has the feature disabled' do
          expect(FeatureManagement.identity_pki_disabled?).to be_falsey
        end
      end
    end

    describe '#development_and_piv_cac_entry_enabled?' do
      context 'in development environment' do
        before(:each) do
          allow(Rails.env).to receive(:development?).and_return(true)
        end

        context 'has piv/cac enabled' do
          before(:each) do
            allow(Figaro.env).to receive(:piv_cac_enabled) { 'true' }
          end

          it 'has piv/cac test entry enabled' do
            expect(FeatureManagement.development_and_piv_cac_entry_enabled?).to be_truthy
          end
        end

        context 'has piv/cac disabled' do
          before(:each) do
            allow(Figaro.env).to receive(:piv_cac_enabled) { 'false' }
          end

          it 'has piv/cac test entry disabled' do
            expect(FeatureManagement.development_and_piv_cac_entry_enabled?).to be_falsey
          end
        end
      end

      context 'in production environment' do
        before(:each) do
          allow(Rails.env).to receive(:production?).and_return(true)
          allow(Rails.env).to receive(:development?).and_return(false)
        end

        context 'has piv/cac enabled' do
          before(:each) do
            allow(Figaro.env).to receive(:piv_cac_enabled) { 'true' }
          end

          it 'has piv/cac test entry disabled' do
            expect(FeatureManagement.development_and_piv_cac_entry_enabled?).to be_falsey
          end
        end

        context 'has piv/cac disabled' do
          before(:each) do
            allow(Figaro.env).to receive(:piv_cac_enabled) { 'false' }
          end

          it 'has piv/cac test entry disabled' do
            expect(FeatureManagement.development_and_piv_cac_entry_enabled?).to be_falsey
          end
        end
      end
    end

    describe '#recaptcha_enabled?' do
      context 'when recaptcha is enabled 100 percent' do
        before do
          allow(Figaro.env).to receive(:recaptcha_enabled_percent).and_return('100')
        end

        it 'enables the feature when the session is new' do
          session = {}
          expect(FeatureManagement.recaptcha_enabled?(session, true)).to eq(true)
        end

        it 'enables the feature when the session is old' do
          session = {}
          expect(FeatureManagement.recaptcha_enabled?(session, true)).to eq(true)
          expect(FeatureManagement.recaptcha_enabled?(session, false)).to eq(true)
        end
      end

      context 'when recaptcha is enabled 0 percent' do
        before do
          allow(Figaro.env).to receive(:recaptcha_enabled_percent).and_return('0')
        end

        it 'disables the feature when the session is new' do
          session = {}
          expect(FeatureManagement.recaptcha_enabled?(session, true)).to eq(false)
        end

        it 'disables the feature when the session is old' do
          session = {}
          expect(FeatureManagement.recaptcha_enabled?(session, true)).to eq(false)
          expect(FeatureManagement.recaptcha_enabled?(session, false)).to eq(false)
        end
      end

      context 'when recaptcha is enabled 50 percent' do
        before do
          allow(Figaro.env).to receive(:recaptcha_enabled_percent).and_return('50')
        end

        it 'enables the feature when the session is new and random number is 70' do
          session = {}
          allow(SecureRandom).to receive(:random_number).and_return(70)
          expect(FeatureManagement.recaptcha_enabled?(session, true)).to eq(true)
        end

        it 'disables the feature when the session is new and random number is 30' do
          session = {}
          allow(SecureRandom).to receive(:random_number).and_return(30)
          expect(FeatureManagement.recaptcha_enabled?(session, true)).to eq(false)
        end

        it 'enables the feature when the session is old and the random number is 70' do
          session = {}
          allow(SecureRandom).to receive(:random_number).and_return(70)
          expect(FeatureManagement.recaptcha_enabled?(session, true)).to eq(true)
          expect(FeatureManagement.recaptcha_enabled?(session, false)).to eq(true)
        end

        it 'disables the feature when the session is old and the random number is 30' do
          session = {}
          allow(SecureRandom).to receive(:random_number).and_return(30)
          expect(FeatureManagement.recaptcha_enabled?(session, true)).to eq(false)
          expect(FeatureManagement.recaptcha_enabled?(session, false)).to eq(false)
        end
      end
    end
  end

  describe '#disallow_all_web_crawlers?' do
    it 'returns true when Figaro setting is true' do
      allow(Figaro.env).to receive(:disallow_all_web_crawlers) { 'true' }

      expect(FeatureManagement.disallow_all_web_crawlers?).to eq(true)
    end

    it 'returns false when Figaro setting is false' do
      allow(Figaro.env).to receive(:disallow_all_web_crawlers) { 'false' }

      expect(FeatureManagement.disallow_all_web_crawlers?).to eq(false)
    end
  end
end
