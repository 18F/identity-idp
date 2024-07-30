# frozen_string_literal: true

class ManageableAuthenticatorComponent < BaseComponent
  attr_reader :configuration,
              :user_session,
              :manage_api_url,
              :manage_url,
              :custom_strings,
              :tag_options

  validate :validate_configuration_methods

  def initialize(
    configuration:,
    user_session:,
    manage_api_url:,
    manage_url:,
    custom_strings: {},
    **tag_options
  )
    @configuration = configuration
    @user_session = user_session
    @manage_api_url = manage_api_url
    @manage_url = manage_url
    @custom_strings = custom_strings
    @tag_options = tag_options
  end

  def reauthentication_url
    account_reauthentication_path(manage_authenticator: unique_id)
  end

  def unique_id
    @unique_id ||= [configuration.class.name.downcase, configuration.id].join('-')
  end

  def strings
    default_strings.merge(custom_strings)
  end

  delegate :reauthenticate_at, to: :auth_methods_session

  private

  def validate_configuration_methods
    [:name, :id, :created_at].each do |method|
      next if configuration.respond_to?(method)
      errors.add(
        :configuration,
        :missing_method,
        message: "`configuration` must respond to `#{method}`",
      )
    end
  end

  def auth_methods_session
    @auth_methods_session ||= AuthMethodsSession.new(user_session:)
  end

  def default_strings
    {
      renamed: t('components.manageable_authenticator.renamed'),
      delete_confirm: t('components.manageable_authenticator.delete_confirm'),
      deleted: t('components.manageable_authenticator.deleted'),
      manage_accessible_label: t('components.manageable_authenticator.manage_accessible_label'),
    }
  end
end
