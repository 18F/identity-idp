# frozen_string_literal: true

class RulesOfUseForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  validate :validate_terms_accepted

  attr_reader :terms_accepted

  def initialize(user)
    @user = user
  end

  def validate_terms_accepted
    return if @terms_accepted

    errors.add(:terms_accepted, t('forms.validation.required_checkbox'), type: :required_checkbox)
  end

  def submit(params)
    @terms_accepted = params[:terms_accepted] == '1'
    if valid?
      process_successful_submission
    else
      self.success = false
    end

    FormResponse.new(success: success, errors: errors)
  end

  private

  attr_accessor :success, :user

  def process_successful_submission
    self.success = true
    UpdateUser.new(user: user, attributes: { accepted_terms_at: Time.zone.now }).call
  end
end
