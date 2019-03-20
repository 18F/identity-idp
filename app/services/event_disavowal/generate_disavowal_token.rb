module EventDisavowal
  class GenerateDisavowalToken
    attr_reader :event, :disavowal_token

    def initialize(event)
      @event = event
    end

    def call
      generate_disavowal_token
      fingerprint_and_save_disavowal_token
      event.disavowal_token
    end

    private

    def generate_disavowal_token
      event.disavowal_token = SecureRandom.urlsafe_base64(32)
    end

    def fingerprint_and_save_disavowal_token
      event.update!(
        disavowal_token_fingerprint: Pii::Fingerprinter.fingerprint(event.disavowal_token),
      )
    end
  end
end
