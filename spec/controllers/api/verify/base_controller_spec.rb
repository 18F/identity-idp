require 'rails_helper'

describe Api::Verify::BaseController do
  describe '#show' do
    subject(:response) { get :show }

    context 'without REQUIRED_STEP constant defined' do
      controller Api::Verify::BaseController do
        def show; end
      end

      before { routes.draw { get '/' => 'api/verify/base#show' } }

      it 'raises an exception' do
        expect { response }.to raise_error(NotImplementedError)
      end
    end
  end
end
