require 'rails_helper'

describe DashboardController do
  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_filters(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end
end
