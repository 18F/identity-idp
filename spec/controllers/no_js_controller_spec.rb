require 'rails_helper'

RSpec.describe NoJsController do
  describe '#index' do
    let(:location) { 'example' }
    subject(:response) { get :index, params: { location: } }

    before do
      stub_analytics
    end

    it 'returns empty css' do
      expect(response.content_type.split(';').first).to eq('text/css')
      expect(response.body).to be_empty
    end

    it 'assigns session key' do
      response

      expect(session[NoJsController::SESSION_KEY]).to eq(true)
    end

    it 'logs an event' do
      response

      expect(@analytics).to have_logged_event(:no_js_detect_stylesheet_loaded, location:)
    end
  end
end
