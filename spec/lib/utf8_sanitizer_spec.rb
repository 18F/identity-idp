require 'rails_helper'

RSpec.describe Utf8Sanitizer do
  include Rack::Test::Methods

  let(:inner_app) do
    proc { |env| [200, { 'Content-Type' => 'text/plain' }, ['OK']] }
  end

  subject(:app) { Utf8Sanitizer.new(inner_app) }

  context 'with valid strings' do
    it 'passes through' do
      post '/test', body: 'hiii', params: { hi: 'hiii' }

      expect(last_response).to be_ok
    end
  end

  context 'with invalid utf8' do
    it '400s' do
      get '/test', params: { hi: "hi \xFFFFFFFFFFFF" }
      expect(last_response).to be_bad_request
    end
  end
end
