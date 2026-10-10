# frozen_string_literal: true

module AttemptsApi
  # Decides whether a verified person's stored identity-proofing (`idv-*`) Attempts events may be
  # released to a given recipient now. The history is released to each recipient at most once,
  # tracked on the profile's `UserProofingEvent`.
  #
  # The direct sign-in path additionally requires that the service provider asked for identity
  # proofing; a delegated release to an agency does not, because the agency did not make the
  # request, so that check stays with the caller.
  class HistoricalReleaseCheck
    attr_reader :profile, :sp

    # @param profile [Profile, nil] the person's active profile
    # @param sp [ServiceProvider] the recipient
    def initialize(profile:, sp:)
      @profile = profile
      @sp = sp
    end

    # @return [Array(Boolean, Symbol|nil)] whether to release, and the reason when not
    def call
      user_proofing_event = profile&.user_proofing_event
      return false, :no_user_proofing_event if user_proofing_event.blank?
      return false, :already_sent if user_proofing_event.already_sent_to_sp?(sp.id)
      return false, :no_encrypted_file_reference if profile.encrypted_attempts_file_reference.blank?

      [true, nil]
    end
  end
end
