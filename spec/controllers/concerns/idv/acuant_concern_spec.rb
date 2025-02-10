require 'rails_helper'

RSpec.describe Idv::AcuantConcern, :controller do
  controller ApplicationController do
    include Idv::AcuantConcern

    before_action :override_csp_to_allow_acuant
    def index; end
  end

  let(:session_uuid) { SecureRandom.uuid }
  let(:default_sdk_version) { IdentityConfig.store.idv_acuant_sdk_version_default }
  let(:alternate_sdk_version) { IdentityConfig.store.idv_acuant_sdk_version_alternate }

  let(:ab_test_bucket) { nil }

  subject(:variables) { controller.acuant_sdk_upgrade_a_b_testing_variables }

  before do
    allow(controller).to receive(:document_capture_session_uuid)
      .and_return(session_uuid)

    # ACUANT_SDK is frozen, so we have to work with a copy of it
    ab_test = AbTests::ACUANT_SDK.dup
    allow(ab_test).to receive(:bucket).and_return(ab_test_bucket)
    stub_const(
      'AbTests::ACUANT_SDK',
      ab_test,
    )
  end

  context 'with acuant sdk upgrade A/B testing disabled' do
    let(:session_uuid) { SecureRandom.uuid }

    before do
      allow(IdentityConfig.store)
        .to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled)
        .and_return(false)
    end

    context 'and A/B test specifies the older acuant version' do
      before do
        allow(AbTests::ACUANT_SDK).to receive(:bucket).and_return(nil)
      end

      it 'passes correct variables and acuant version when older is specified' do
        expect(variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(false)
        expect(variables[:use_alternate_sdk]).to eq(false)
        expect(variables[:acuant_version]).to eq(default_sdk_version)
      end
    end
  end

  context 'with acuant sdk upgrade A/B testing enabled' do
    before do
      allow(IdentityConfig.store)
        .to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled)
        .and_return(true)
    end

    context 'and A/B test specifies the newer acuant version' do
      let(:ab_test_bucket) { :use_alternate_sdk }

      it 'passes correct variables and acuant version when newer is specified' do
        expect(variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(true)
        expect(variables[:use_alternate_sdk]).to eq(true)
        expect(variables[:acuant_version]).to eq(alternate_sdk_version)
      end
    end

    context 'and A/B test specifies the older acuant version' do
      let(:ab_test_bucket) { :default }

      it 'passes correct variables and acuant version when older is specified' do
        expect(variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(true)
        expect(variables[:use_alternate_sdk]).to eq(false)
        expect(variables[:acuant_version]).to eq(default_sdk_version)
      end
    end
  end

  describe '#override_csp_to_allow_acuant' do
    it 'sets the headers for the document capture step' do
      get :index, params: { step: 'document_capture' }

      csp = response.request.content_security_policy
      expect(csp.script_src).to include("'unsafe-eval'")
      expect(csp.style_src).to include("'unsafe-inline'")
      expect(csp.img_src).to include('blob:')
    end

    context 'with content security policy directives for style-src' do
      let(:csp_nonce_directives) { ['style-src'] }

      before do
        request.content_security_policy_nonce_directives = csp_nonce_directives
      end

      it 'removes style-src nonce directive to allow all unsafe inline styles' do
        get :index, params: { step: 'document_capture' }

        csp = parse_content_security_policy

        expect(csp['style-src']).to_not include(/'nonce-.+'/)

        # Ensure that the default configuration is not mutated as a result of the request-specific
        # revisions to the content security policy.
        expect(csp_nonce_directives).to eq(['style-src'])
      end
    end
  end

  def parse_content_security_policy
    header = response.request.content_security_policy.build(
      controller,
      request.content_security_policy_nonce_generator.call(request),
      request.content_security_policy_nonce_directives,
    )
    header.split(';').each_with_object({}) do |directive, result|
      tokens = directive.strip.split(/\s+/)
      key = tokens.first
      rules = tokens[1..-1]
      result[key] = rules
    end
  end
end
