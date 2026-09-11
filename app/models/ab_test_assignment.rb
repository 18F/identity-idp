# frozen_string_literal: true

class AbTestAssignment < ApplicationRecord
  OPT_OUT_BUCKET = 'opt_out'

  class << self
    def bucket(**)
      find_by(**)&.bucket&.to_sym
    end

    def opt_out!(experiment:, discriminator:)
      find_or_initialize_by(experiment:, discriminator:).update!(bucket: OPT_OUT_BUCKET)
    end
  end
end
