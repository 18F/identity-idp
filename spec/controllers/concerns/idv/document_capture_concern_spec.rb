require 'rails_helper'

RSpec.describe Idv::DocumentCaptureConcern, type: :controller do
  controller ApplicationController do
    include Idv::DocumentCaptureConcern

    before_action :override_document_capture_step_csp

    def index; end
  end

  describe '#override_document_capture_step_csp' do
    it 'sets the headers for the document capture step' do
      get :index, params: { step: 'document_capture' }

      csp = response.request.headers.env['secure_headers_request_config'].csp
      expect(csp.script_src).to include("'unsafe-eval'")
      expect(csp.style_src).to include("'unsafe-inline'")
      expect(csp.img_src).to include('blob:')
    end

    it 'does not set headers for any other step' do
      get :index, params: { step: 'some_other_step' }

      secure_header_config = response.request.headers.env['secure_headers_request_config']
      expect(secure_header_config).to be_nil
    end
  end
end
