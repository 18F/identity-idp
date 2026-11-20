# frozen_string_literal: true

module NDS
  # NDS variant of ManageableAuthenticatorComponent, for the dashboard Security tab (NDS
  # layout only). It drives the same <lg-manageable-authenticator> element and APIs, laid
  # out as a DS .auth-methods__row: the method's nickname and details with a Manage
  # button. Manage swaps the row for the nickname field with Delete and Save, as in the
  # Figma Security tab.
  #
  # The element opts into `inline-rename`: Manage opens the rename form directly, a saved
  # rename returns to the row, and the element toggles each part's `hidden` attribute.
  # That keeps the legacy sidecar stylesheet, which styles and toggles the legacy markup,
  # off NDS pages.
  class ManageableAuthenticatorComponent < ::ManageableAuthenticatorComponent
    attr_reader :nickname_label

    def self.stylesheets
      []
    end

    # @param [String] nickname_label Label for the nickname field.
    # @param [String, nil] details Text after the nickname. Defaults to the created date.
    def initialize(nickname_label:, details: nil, **options)
      super(**options)
      @nickname_label = nickname_label
      @details = details
    end

    def details
      @details || t(
        'components.manageable_authenticator.created_on',
        date: l(configuration.created_at, format: :event_date),
      )
    end

    # Field names and ids are scoped to the configuration, so that several authenticators
    # on one page keep their ids unique.
    def field_scope
      "manageable_authenticator_#{unique_id.underscore}"
    end

    def manage_label_id
      "manageable-authenticator-manage-accessible-label-#{unique_id}"
    end
  end
end
