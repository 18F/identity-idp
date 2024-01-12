require 'rails_helper'

RSpec.describe Idv::PluginAware, type: :controller do
  controller ApplicationController do
    include Idv::PluginAware

    require_plugin :my_test_plugin

    def index
      do_some_work
      render plain: 'Hello'
    end

    private

    def do_some_work
      # this is here so we can spy on it
    end
  end

  let(:plugin_manager) { PluginManager.new }

  let(:plugin_class) { Class.new }

  before do
    allow(controller).to receive(:plugin_manager).and_return(plugin_manager)
  end

  context 'plugin is available' do
    before do
      plugin_manager.add_plugin :my_test_plugin, plugin_class.new
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
        expect(controller).not_to receive(:do_some_work)
        get :index
        expect(response).to have_http_status(404)
      end
    end
  end
end
