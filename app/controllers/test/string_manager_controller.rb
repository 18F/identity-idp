# frozen_string_literal: true

module Test
  class StringManagerController < ::ApplicationController
    layout 'base'

    skip_before_action :reset_strings_manager

    def index; end
  end
end
