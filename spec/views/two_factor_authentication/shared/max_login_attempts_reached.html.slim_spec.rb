require 'rails_helper'

describe 'two_factor_authentication/shared/max_login_attempts_reached.html.slim' do
  context 'locked out account' do
    it 'includes localized error message with time remaining' do
      @user_decorator = instance_double(UserDecorator)
      allow(@user_decorator).to receive(:lockout_time_remaining_in_words).and_return('1000 years')

      render

      expect(rendered).to include(t('titles.account_locked'))
      expect(rendered).to include(t('devise.two_factor_authentication.max_login_attempts_reached'))
      expect(rendered).to include('1000 years')
    end
  end
end
