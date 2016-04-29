require 'rails_helper'

describe 'devise/two_factor_authentication/max_login_attempts_reached.html.slim' do
  context 'locked out account' do
    it 'includes localized error message with time remaining' do
      user_decorator = instance_double(UserDecorator)
      allow(view).to receive(:user_decorator).and_return(user_decorator)
      allow(user_decorator).to receive(:lockout_time_remaining_in_words).and_return('10 minutes')

      render

      expect(rendered).to include(
        t('devise.two_factor_authentication.max_login_attempts_reached',
          time_remaining: '10 minutes'))
    end
  end
end
