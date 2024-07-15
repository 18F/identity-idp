# frozen_string_literal: true

class SelectEmailForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  def initialize(user)
    @user = user
  end

  def submit(params)
    @selected_email_form = params[:select_email_form]

    success = valid?

    FormResponse.new(success: success, errors: errors)
  end
end
