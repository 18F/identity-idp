require 'rails_helper'

RSpec.describe PagesController do
  describe 'analytics' do
    controller do
      def index
        render plain: 'Hello'
      end
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

    it 'does not load session' do
      routes.draw { get 'foo' => 'pages#page_not_found' }

      get :page_not_found

      expect(session).to be_empty
    end
  end

  describe 'content expiry' do
    controller do
      def index
        render plain: 'Hello'
      end
    end

    it 'does not set headers to disable cache' do
      routes.draw { get 'foo' => 'pages#page_not_found' }

      get :page_not_found

      expect(response.headers['Cache-Control']).to_not eq 'no-store'
      expect(response.headers['Pragma']).to_not eq 'no-cache'
    end
  end
end
