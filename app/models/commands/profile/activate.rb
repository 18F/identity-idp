# frozen_string_literal: true

module Commands
  class Profile::Activate
    include Command

    attributes :profile, :metadata

    private def build_event
      Events::Profile::Activated.new(
        profile: profile,
        metadata: metadata,
      )
    end

    private def noop?
      profile.active?
    end
  end
end
