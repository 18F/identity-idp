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

      expect(@analytics).to_not receive(:track_event).
        with(Analytics::GET_REQUEST, controller: 'pages', action: 'index')

      get :index
    end

    it 'tracks the page_not_found event' do
      routes.draw { get 'foo' => 'pages#page_not_found' }

      stub_analytics

      expect(@analytics).to receive(:track_event).with(Analytics::PAGE_NOT_FOUND, path: '/foo')

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

  describe '#deploy_json' do
    context 'when there is no deploy.json' do
      it 'renders an empty JSON object' do
        get :deploy_json
        expect(response.body).to eq('{}')
      end
    end

    context 'when there is a deploy.json' do
      let(:deploy_json) { { 'env' => 'development' } }

      before do
        FileUtils.mkdir_p(Rails.root.join('public', 'api'))
        File.open(Rails.root.join('public', 'api', 'deploy.json'), 'w') do |file|
          file.puts deploy_json.to_json
        end
      end

      it 'renders the contents of deploy.json' do
        get :deploy_json
        expect(JSON.parse(response.body)).to eq(deploy_json)
      end

      after { FileUtils.rm_rf(Rails.root.join('public', 'api')) }
    end
  end
end
