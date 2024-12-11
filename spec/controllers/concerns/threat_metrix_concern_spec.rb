# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ThreatMetrixConcern, type: :controller do
  controller ApplicationController do
    include ThreatMetrixConcern

    before_action :override_csp_for_threat_metrix

    def index; end
  end

  describe '#override_csp_for_threat_metrix' do
    let(:ff_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:proofing_device_profiling)
        .and_return(ff_enabled ? :enabled : :disabled)
    end

    context 'ff is set' do
      it 'modifies CSP headers' do
        get :index

        csp = response.request.content_security_policy

        aggregate_failures do
          expect(csp.directives['script-src']).to include('h.online-metrix.net')
          expect(csp.directives['script-src']).to include("'unsafe-eval'")

          expect(csp.directives['style-src']).to include("'unsafe-inline'")

          expect(csp.directives['child-src']).to include('h.online-metrix.net')

          expect(csp.directives['connect-src']).to include('h.online-metrix.net')

          expect(csp.directives['img-src']).to include('*.online-metrix.net')
        end
      end

      context 'with content security policy directives for style-src' do
        let(:csp_nonce_directives) { ['style-src'] }

        before do
          request.content_security_policy_nonce_directives = csp_nonce_directives
        end

        it 'removes style-src nonce directive to allow all unsafe inline styles' do
          get :index

          csp = parse_content_security_policy

          expect(csp['style-src']).to_not include(/'nonce-.+'/)

          # Ensure that the default configuration is not mutated as a result of the request-specific
          # revisions to the content security policy.
          expect(csp_nonce_directives).to eq(['style-src'])
        end
      end
    end

    context 'ff is not set' do
      let(:ff_enabled) { false }
      it 'does not modify CSP headers' do
        get :index
        secure_header_config = response.request.headers.env['secure_headers_request_config']
        expect(secure_header_config).to be_nil
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
