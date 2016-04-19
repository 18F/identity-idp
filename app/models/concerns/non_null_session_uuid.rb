module NonNullSessionUuid
  extend ActiveSupport::Concern

  included do
    before_create :generate_session_uuid
  end

  def generate_session_uuid
    self.session_uuid = '_' + SecureRandom.uuid
  end
end
