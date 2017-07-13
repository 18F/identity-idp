require 'rails_helper'

RSpec.describe 'Missing pages and assets', type: :request do
  describe 'missing page' do
    it 'responds with 404' do
      get '/nonexistent-page'

      expect(response.status).to eq 404
    end
  end

  describe 'missing PNG' do
    it 'responds with 404' do
      get '/mobile-icon.png'

      expect(response.status).to eq 404
    end
  end

  describe 'missing CSS' do
    it 'responds with 404' do
      get '/application-random-hash.css'

      expect(response.status).to eq 404
    end
  end

  describe 'missing JS' do
    it 'responds with 404' do
      get '/application-random-hash.js'

      expect(response.status).to eq 404
    end
  end
end
