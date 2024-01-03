require 'rails_helper'
require 'custom_devise_failure_app'

RSpec.describe CustomDeviseFailureApp do
  subject(:failure_app) { CustomDeviseFailureApp.new }

  let(:message) { :invalid }
  let(:env) { { 'warden' => OpenStruct.new(message:) } }
  let(:request) { ActionDispatch::Request.new(env) }

  before do
    failure_app.set_request!(request)
  end

  describe '#redirect_url' do
    it 'defers to to the default implementation' do
      expect_any_instance_of(Devise::FailureApp).to receive(:redirect_url)

      failure_app.redirect_url
    end

    context 'with custom redirect url assigned in request env' do
      let(:custom_redirect_url) { '/redirect' }
      let(:env) { super().merge({ 'devise_invalid_failure_redirect_url' => custom_redirect_url }) }

      it 'returns the custom redirect url' do
        expect(failure_app.redirect_url).to eq(custom_redirect_url)
      end
    end
  end
end
