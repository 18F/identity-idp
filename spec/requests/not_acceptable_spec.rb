require 'rails_helper'

RSpec.describe 'Invalid content type request', type: :request do
  describe 'valid format' do
    it 'succeeds when requesting html' do
      get '/login/piv_cac'
      expect(response.status).to eq 200
    end

    it 'fails with an invalid format' do
      get '/login/piv_cac.xml'
      expect(response.status).to eq 406
    end
  end
end
