require 'rails_helper'

describe 'i18n requests' do
  context 'with CSRF errors' do
    before do
      ActionController::Base.allow_forgery_protection = true
    end

    after do
      ActionController::Base.allow_forgery_protection = false
    end

    it 'renders the page in the language of the current request despite CSRF errors' do
      get root_path(locale: :es)

      post root_path(
        locale: :en,
        params: { user: { email: 'asdf@gmail.com', passowrd: '123abcdef' } }
      )
      get response.headers['Location']

      expect(response.body).to include(t('errors.invalid_authenticity_token', locale: :en))
      expect(response.body).to_not include(t('errors.invalid_authenticity_token', locale: :es))
    end
  end
end
