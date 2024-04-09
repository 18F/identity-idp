# frozen_string_literal: true

module Vot
  ComponentValue = Data.define(:name, :description, :implied_component_values, :requirements).freeze
end
