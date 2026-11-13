# frozen_string_literal: true

module Test
  # Controller that echoes back session info, only for testing
  class SessionDataController < ApplicationController
    include LocalEnvironmentOnlyConcern

    def index
      render json: session.to_h
    end
  end
end
