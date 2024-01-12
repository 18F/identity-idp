require 'rails_helper'

RSpec.describe Idv::PluginAware, type: :controller do
  controller ApplicationController do
    include Idv::PluginAware

    require_plugin :my_test_plugin

    def index
      render plain: 'Hello'
    end
  end

  class MyTestPlugin
  end

  before do
    PluginManager.reset!
  end

  context 'plugin is available' do
    before do
      PluginManager.add_plugin :my_test_plugin, MyTestPlugin.new
    end
    describe '#index' do
      it 'returns a 200' do
        get :index
        expect(response).to have_http_status(200)
      end
    end
  end

  context 'plugin is not available' do
    describe '#index' do
      it 'returns a 404' do
        get :index
        expect(response).to have_http_status(404)
      end
    end
  end
end
