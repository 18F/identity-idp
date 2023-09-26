# frozen_string_literal: true

module Commands
  class Profile::Create
    include Command

    attributes :user_id, :metadata

    private def build_event
      Events::Profile::Created.new(
        user_id: user.id,
        metadata: metadata,
      )
    end
  end
end
