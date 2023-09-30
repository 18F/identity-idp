# frozen_string_literal: true

module Commands
  module Profile
    class Create
      include Command

      attributes :user, :metadata

      private def build_event
        Events::Profile::Created.new(
          user_id: user.id,
          metadata: metadata,
        )
      end
    end
  end
end
