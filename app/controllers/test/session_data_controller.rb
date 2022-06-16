module Test
  # Controller that echoes back session info, only for testing
  class SessionDataController < ApplicationController
    def index
      render json: session.to_h
    end
  end
end
