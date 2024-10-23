# frozen_string_literal: true

module Test
  class DatabaseTablesController < ApplicationController
    def index
      # Ensure all ActiveRecord classes are loaded
      Rails.application.eager_load!

      ActiveRecord::Base.descendants.each do |model|
        next if model.abstract_class?

        model.first
      end

      render plain: 'Success'
    end
  end
end
