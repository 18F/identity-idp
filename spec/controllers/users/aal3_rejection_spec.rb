require 'rails_helper'

describe Users::Aal3RejectionController do
  describe '#show' do
    it 'renders the AAL3 required page successfully' do
      get :show
      expect(response).to render_template('two_factor_authentication/options/no_option')
    end
  end
end
