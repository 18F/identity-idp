class RulesOfUseForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  validate :validate_terms_accepted

  attr_reader :terms_accepted

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  def initialize(user:, analytics:)
    @user = user
    @analytics = analytics
  end

  def validate_terms_accepted
    return if @terms_accepted

    errors.add(:terms_accepted, t('errors.registration.terms'))
  end

  def submit(params, instructions = nil)
    @terms_accepted = params[:terms_accepted] == 'true'
    if valid?
      process_successful_submission
    else
      self.success = false
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :success, :user

  def process_successful_submission
    self.success = true
    user.accepted_terms_at = Time.zone.now
    user.save!
  end

  def extra_analytics_attributes
    {
      user_id: user.uuid,
    }
  end
end
