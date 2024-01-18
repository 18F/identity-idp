class ManageableAuthenticatorComponent < BaseComponent
  attr_reader :configuration,
              :user_session,
              :manage_api_url,
              :manage_url,
              :custom_strings,
              :tag_options

  def initialize(
    configuration:,
    user_session:,
    manage_api_url:,
    manage_url:,
    custom_strings: {},
    **tag_options
  )
    if ![:name, :id, :created_at].all? { |method| configuration.respond_to?(method) }
      raise ArgumentError, '`configuration` must respond to `name`, `id`, `created_at`'
    end

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
