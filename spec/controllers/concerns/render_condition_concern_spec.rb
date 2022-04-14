require 'rails_helper'

RSpec.describe RenderConditionConcern, type: :controller do
  let(:all_feature?) { false }
  let(:show_feature?) { false }

  controller ApplicationController do
    include RenderConditionConcern

    check_or_render_not_found -> { FeatureManagement.all_feature? }
    check_or_render_not_found -> { FeatureManagement.show_feature? }, only: [:show]

    def index
      render plain: ''
    end

    def show
      render plain: ''
    end
  end

  before do
    allow(FeatureManagement).to receive(:all_feature?).and_return(all_feature?)
    allow(FeatureManagement).to receive(:show_feature?).and_return(show_feature?)

    routes.draw do
      get 'index' => 'anonymous#index'
      get 'show' => 'anonymous#show'
    end
  end

  describe '#index' do
    subject(:response) { get :index }

    it 'renders 404' do
      expect(response).to be_not_found
    end

    context 'all feature enabled' do
      let(:all_feature?) { true }

      it 'renders page' do
        expect(response).to be_ok
      end

      context 'show feature enabled' do
        let(:show_feature?) { true }

        it 'renders page' do
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#show' do
    subject(:response) { get :show }

    it 'renders 404' do
      expect(response).to be_not_found
    end

    context 'all feature enabled' do
      let(:all_feature?) { true }

      it 'renders 404' do
        expect(response).to be_not_found
      end

      context 'show feature enabled' do
        let(:show_feature?) { true }

        it 'renders page' do
          expect(response).to be_ok
        end
      end
    end
  end
end
