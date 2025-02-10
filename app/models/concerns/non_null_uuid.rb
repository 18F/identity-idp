# frozen_string_literal: true

# Default populates a uuid field with a v4 UUID.
module NonNullUuid
  extend ActiveSupport::Concern

  included do
    before_create :generate_uuid
  end

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
