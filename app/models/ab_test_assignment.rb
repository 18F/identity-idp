# frozen_string_literal: true

class AbTestAssignment < ApplicationRecord
  OPT_OUT_BUCKET = 'opt_out'

  class << self
    def bucket(**)
      find_by(**)&.bucket&.to_sym
    end

    def opt_out!(experiment:, discriminator:)
      transaction do
        assignment = find_by(experiment:, discriminator:)
        return false if assignment.nil?
        assignment.update!(bucket: OPT_OUT_BUCKET)
        true
      end
    end
  end
end
