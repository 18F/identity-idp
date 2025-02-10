# frozen_string_literal: true

class PivCacAuthenticationSetupBasePresenter < SetupPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :form, :user, :fully_authenticated

  def initialize(current_user, user_fully_authenticated, form)
    @current_user = current_user
    @user_fully_authenticated = user_fully_authenticated
    @form = form
  end
end
