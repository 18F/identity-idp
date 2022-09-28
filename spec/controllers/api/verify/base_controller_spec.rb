require 'rails_helper'

describe Api::Verify::BaseController do
  describe '#create' do
    subject(:response) { post :create }

    controller Api::Verify::BaseController do

      def create
        render json: {}
      end
    end

    before { routes.draw { get '/' => 'api/verify/base#create' } }

    it 'renders as unauthorized (401)' do
      expect(response.status).to eq(401)
    end

    context 'with authenticated user' do
      before { stub_sign_in }

      it 'renders as ok (200)' do
        expect(response.status).to eq(200)
      end

      context 'with request forgery protection enabled' do
        around do |ex|
          ActionController::Base.allow_forgery_protection = true
          ex.run
          ActionController::Base.allow_forgery_protection = false
        end

        it 'renders as ok (200)' do
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
