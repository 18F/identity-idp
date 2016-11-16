class ProfileController < ApplicationController
  before_action :confirm_two_factor_authenticated
  layout 'card_wide'

  def index
    cacher = Pii::Cacher.new(current_user, user_session)
    @decrypted_pii = cacher.fetch
    @recovery_code = flash[:recovery_code]
    flash.delete(:recovery_code)
  end
end
