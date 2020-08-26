require 'rails_helper'

RSpec.describe Users::EmailsController do
  describe '#verify' do
    context 'with malformed payload' do
      it 'does not blow up' do
        expect { get :verify, params: { request_id: { foo: 'bar' } } }.
          to_not raise_error
      end
    end
  end
end
