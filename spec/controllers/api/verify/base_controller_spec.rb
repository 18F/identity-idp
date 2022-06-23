require 'rails_helper'

describe Api::Verify::BaseController do
  describe '#create' do
    subject(:response) { post :create }

    context 'without required_step defined' do
      controller Api::Verify::BaseController do
        def create; end
      end

      before { routes.draw { post '/' => 'api/verify/base#create' } }

      it 'raises an exception' do
        expect { response }.to raise_error(NotImplementedError)
      end
    end

    context 'with required_step defined' do
      controller Api::Verify::BaseController do
        self.required_step = 'example'

        def create
          render json: {}
        end
      end

      before { routes.draw { get '/' => 'api/verify/base#create' } }

      it 'renders as not found (404)' do
        expect(response.status).to eq(404)
      end

      context 'with step enabled' do
        before do
          allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(['example'])
        end

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

    context 'with an explicitly nil required_step' do
      controller Api::Verify::BaseController do
        self.required_step = nil

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
      end
    end
  end
end
