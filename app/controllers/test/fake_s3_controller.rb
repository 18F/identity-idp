# frozen_string_literal: true

module Test
  class FakeS3Controller < ApplicationController
    skip_before_action :verify_authenticity_token

    cattr_accessor :data
    self.data ||= {}

    # Intended for use in tests to clear stored data
    def self.clear!
      self.data.clear
    end

    def show
      key = params[:key]

      if self.class.data.key?(key)
        send_data self.class.data[key], type: 'application/octet-stream', filename: key
      else
        render_not_found
      end
    end

    def update
      key = params[:key]

      self.class.data[key] = request.body.read

      render json: {}
    end
  end
end
