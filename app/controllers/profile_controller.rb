class ProfileController < ApplicationController
  before_action :confirm_two_factor_authenticated
  layout 'card_wide'

  def index
    cacher = Pii::Cacher.new(current_user, user_session)

    @view_model = UserProfile::ProfileIndex.new(
      decrypted_pii: cacher.fetch,
      personal_key: flash[:personal_key],
      has_password_reset_profile: current_user.password_reset_profile.present?
    )

    flash.delete(:personal_key)
  end
end
