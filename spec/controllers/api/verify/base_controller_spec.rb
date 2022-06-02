require 'rails_helper'

describe Api::Verify::BaseController do
  describe '#show' do
    subject(:response) { get :show }

    context 'without required_step defined' do
      controller Api::Verify::BaseController do
        def show; end
      end

      before { routes.draw { get '/' => 'api/verify/base#show' } }

      it 'raises an exception' do
        expect { response }.to raise_error(NotImplementedError)
      end
    end

    context 'with required_step defined' do
      controller Api::Verify::BaseController do
        self.required_step = 'example'

        def show
          render json: {}
        end
      end

      before { routes.draw { get '/' => 'api/verify/base#show' } }

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
        end
      end
    end
  end
end
