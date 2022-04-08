require 'rails_helper'

RSpec.describe FeatureFlaggedConcern, type: :controller do
  controller ApplicationController do
    include FeatureFlaggedConcern

    feature_flagged :all_feature
    feature_flagged :show_feature, only: [:show]

    def index
      render plain: ''
    end

    def show
      render plain: ''
    end
  end

  let(:all_feature) { false }
  let(:show_feature) { false }

  before do
    allow(IdentityConfig.store).to receive(:all_feature).and_return(all_feature)
    allow(IdentityConfig.store).to receive(:show_feature).and_return(show_feature)

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
      let(:all_feature) { true }

      it 'renders page' do
        expect(response).to be_ok
      end

      context 'show feature enabled' do
        let(:show_feature) { true }

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
      let(:all_feature) { true }

      it 'renders 404' do
        expect(response).to be_not_found
      end

      context 'show feature enabled' do
        let(:show_feature) { true }

        it 'renders page' do
          expect(response).to be_ok
        end
      end
    end
  end
end
