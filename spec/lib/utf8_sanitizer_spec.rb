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

    it '400s with nested bad params' do
      get '/test', params: { hi: { hi: { hi: "hi \xFFFFFFFFFFFF" } } }
      expect(last_response).to be_bad_request
    end
  end

  context 'null bytes' do
    it 'allows null bytes inside of files' do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("\x00"), 'text/plain', original_filename: 'null.txt'
      )
      post '/test', body: { some_file: file }
      expect(last_response).to be_ok
    end

    it 'blocks null bytes in the params' do
      post '/test', params: { some: ['aaa', { value: "\x00" }] }
      expect(last_response).to be_bad_request
    end

    it 'blocks null bytes in the keys of params' do
      post '/test', params: { "key_\x00" => 'value' }
      expect(last_response).to be_bad_request
    end

    it 'blocks null bytes inside the body' do
      post '/test', body: "\x00"
      expect(last_response).to be_bad_request
    end
  end
end
