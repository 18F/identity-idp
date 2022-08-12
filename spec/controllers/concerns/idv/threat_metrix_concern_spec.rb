# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::ThreatMetrixConcern, type: :controller do
  controller ApplicationController do
    include Idv::ThreatMetrixConcern

    before_action :override_csp_for_threat_metrix

    def index; end
  end

  describe '#override_csp_for_threat_metrix' do
    let(:ff_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:proofing_device_profiling_collecting_enabled).
      and_return(ff_enabled)
    end

    context 'ff is set' do
      it 'modifies CSP headers for SSN step' do
        assert_csp_is_modified 'ssn'
      end

      it 'does not modify CSP headers for any other step' do
        assert_csp_is_not_modified 'some_other_step'
      end
    end

    context 'ff is not set' do
      let(:ff_enabled) { false }
      it 'does not modify CSP headers for SSN step' do
        assert_csp_is_not_modified 'ssn'
      end
      it 'does not modify CSP headers for any other step' do
        assert_csp_is_not_modified 'some_other_step'
      end
    end
  end

  private

  def assert_csp_is_modified(step)
    get :index, params: { step: step }

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

  def assert_csp_is_not_modified(step)
    get :index, params: { step: step }
    secure_header_config = response.request.headers.env['secure_headers_request_config']
    expect(secure_header_config).to be_nil
  end
end
