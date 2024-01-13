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

  let(:plugin_instance) { plugin_class.new }

  before do
    allow(controller).to receive(:plugin_manager).and_return(plugin_manager)
  end

  describe '#require_plugin' do
    context 'plugin is available' do
      before do
        plugin_manager.add_plugin :my_test_plugin, plugin_instance
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

  describe '#trigger_plugin_hook' do
    let(:plugin_class) do
      Class.new do
        def my_awesome_hook(
          user:,
          **rest
        )
        end
      end
    end

    let(:user) { build(:user) }

    let(:profile) { build(:profile) }

    before do
      allow(controller).to receive(:current_user).and_return(user)
      plugin_manager.add_plugin :my_test_plugin, plugin_instance
    end

    it 'includes user' do
      expect(plugin_instance).to receive(:my_awesome_hook).with(
        user: user,
      )
      controller.trigger_plugin_hook(:my_awesome_hook)
    end
  end
end
