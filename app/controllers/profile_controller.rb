class ProfileController < ApplicationController
  before_action :confirm_two_factor_authenticated
  layout 'card_wide'

  def index
    p 'it me!'
    cacher = Pii::Cacher.new(current_user, user_session)

    @view_model = UserProfile::ProfileIndex.new(
      decrypted_pii: cacher.fetch,
      recovery_code: flash[:recovery_code],
      has_password_reset_profile: current_user.password_reset_profile.present?
    )

    flash.delete(:recovery_code)
  end
end
