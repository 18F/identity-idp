module AccountStateChecker
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :confirm_two_factor_setup
    before_action :confirm_two_factor_authenticated
  end
end
