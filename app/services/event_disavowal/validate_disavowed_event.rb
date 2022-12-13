module EventDisavowal
  class ValidateDisavowedEvent
    include ActiveModel::Model

    validates :event,
              presence: {
                message: proc { I18n.t('event_disavowals.errors.event_not_found') },
              }
    validate :event_is_not_already_disavowed
    validate :event_disavowment_is_not_expired
    validates_presence_of :user,
                          {
                            message: proc { I18n.t('event_disavowals.errors.no_account') },
                          }

    attr_reader :event

    delegate :user, to: :event, allow_nil: true

    def initialize(event)
      @event = event
    end

    def call
      FormResponse.new(
        success: valid?,
        errors: errors,
        extra: EventDisavowal::BuildDisavowedEventAnalyticsAttributes.call(event),
      )
    end

    private

    def event_is_not_already_disavowed
      return if event.nil?
      return if event.disavowed_at.blank?
      errors.add(
        :event,
        I18n.t('event_disavowals.errors.event_already_disavowed'),
        type: :event_already_disavowed,
      )
    end

    def event_disavowment_is_not_expired
      return if event.nil?
      disavowal_expiration = IdentityConfig.store.event_disavowal_expiration_hours.hours.ago
      return if event.created_at > disavowal_expiration
      errors.add(
        :event,
        I18n.t('event_disavowals.errors.event_disavowal_expired'),
        type: :event_disavowal_expired,
      )
    end
  end
end
