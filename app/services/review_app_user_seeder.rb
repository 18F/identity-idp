# frozen_string_literal: true

class ReviewAppUserSeeder
  REVIEW_APP_USERS = %w[
    logingov-admin@gsa.gov
    logingov-readonly@gsa.gov
    partner-admin@gsa.gov
    partner-developer@gsa.gov
    partner-readonly@gsa.gov
  ].freeze

  DEFAULT_PASSWORD = 'salty pickles'

  def run
    return unless ENV['POSTGRES_HOST']&.include?('.review-app')

    REVIEW_APP_USERS.each_with_index do |email, index|
      next if user_exists?(email)

      create_user(email: email, index: index)
      Rails.logger.info("ReviewAppUserSeeder: Created user #{email}")
    end
  end

  private

  def user_exists?(email)
    User.find_with_email(email).present?
  end

  def create_user(email:, index:)
    user = User.create!

    EmailAddress.create!(
      email: email,
      user: user,
      confirmed_at: Time.zone.now,
    )

    user.reset_password(DEFAULT_PASSWORD, DEFAULT_PASSWORD)

    MfaContext.new(user).phone_configurations.create(
      delivery_preference: user.otp_delivery_preference,
      phone: format('+1 (202) 555-%04d', index),
      confirmed_at: Time.zone.now,
    )

    Event.create(user_id: user.id, event_type: :account_created)
  end
end
