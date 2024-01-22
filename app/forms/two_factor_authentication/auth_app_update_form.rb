module TwoFactorAuthentication
  class AuthAppUpdateForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    attr_reader :user, :configuration_id

    validate :validate_configuration_exists
    validate :validate_unique_name

    def initialize(user:, configuration_id:)
      @user = user
      @configuration_id = configuration_id
    end

    def submit(name:)
      @name = name

      success = valid?
      if valid?
        configuration.name = name
        success = configuration.valid?
        errors.merge!(configuration.errors)
        configuration.save if success
      end

      FormResponse.new(
        success:,
        errors:,
        extra: extra_analytics_attributes,
        serialize_error_details_only: true,
      )
    end

    def name
      return @name if defined?(@name)
      @name = configuration&.name
    end

    def configuration
      @configuration ||= user.auth_app_configurations.find_by(id: configuration_id)
    end

    private

    def validate_configuration_exists
      return if configuration.present?
      errors.add(
        :configuration_id,
        :configuration_not_found,
        message: t('errors.manage_authenticator.internal_error'),
      )
    end

    def validate_unique_name
      return unless user.auth_app_configurations.where.not(id: configuration_id).find_by(name:)
      errors.add(
        :name,
        :duplicate,
        message: t('errors.manage_authenticator.unique_name_error'),
      )
    end

    def extra_analytics_attributes
      { configuration_id: }
    end
  end
end
