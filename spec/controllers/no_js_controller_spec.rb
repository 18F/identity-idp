require 'rails_helper'

describe NoJsController do
  describe '#index' do
    subject(:response) { get :index }

    it 'returns empty css' do
      expect(response.content_type.split(';').first).to eq('text/css')
      expect(response.body).to be_empty
    end

    it 'assigns session key' do
      response

      expect(session[NoJsController::SESSION_KEY]).to eq(true)
    end
  end
end
