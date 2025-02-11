# frozen_string_literal: true

class AbTestAssignment < ApplicationRecord
  class << self
    def bucket(**)
      find_by(**)&.bucket&.to_sym
    end
  end
end
