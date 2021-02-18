require 'rails_helper'

shared_examples_for 'DocumentCaptureConcern' do |next_step:|
  before do
    allow_any_instance_of(Flow::BaseFlow).to receive(:next_step).and_return(next_step)
  end

  if next_step == :document_capture
    it 'overrides CSP' do
      get :show, params: { step: next_step }

      csp = response.request.headers.env['secure_headers_request_config'].csp
      expect(csp.script_src).to include("'unsafe-eval'")
      expect(csp.img_src).to include('blob:')
    end
  else
    it 'does not override CSP' do
      get :show, params: { step: next_step }

      secure_header_config = response.request.headers.env['secure_headers_request_config']
      expect(secure_header_config).to be_nil
    end
  end
end
