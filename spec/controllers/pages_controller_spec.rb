require 'rails_helper'

describe PagesController do
  describe 'analytics' do
    controller do
      def index
        render text: 'Hello'
      end
    end

    it 'skips the track_get_request after_action' do
      stub_analytics

      expect(@analytics).to_not receive(:track_event).with('GET request for pages#index')

      get :index
    end

    it 'tracks the page_not_found event' do
      routes.draw { get 'foo' => 'pages#page_not_found' }

      stub_analytics

      expect(@analytics).to receive(:track_event).with(:page_not_found, path: '/foo')

      get :page_not_found
    end

    it 'returns 404 status' do
      routes.draw { get 'foo' => 'pages#page_not_found' }

      get :page_not_found

      expect(response.status).to eq 404
    end

    it 'renders without a layout' do
      routes.draw { get 'foo' => 'pages#page_not_found' }

      get :page_not_found

      expect(response).to render_template(layout: false)
    end
  end
end
