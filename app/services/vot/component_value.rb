# frozen_string_literal: true

module Vot
  class ComponentValue < Data.define(:name, :description, :implied_component_values, :requirements)
  end.freeze
end
