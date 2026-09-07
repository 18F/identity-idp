# frozen_string_literal: true

module Idv
  # NDS dead end: identity verification currently needs a U.S. phone number,
  # so a user who enters a non-U.S. number on hybrid handoff lands here before
  # investing in document capture.
  class PhoneRequiredController < ApplicationController
    include Idv::AvailabilityConcern

    before_action :confirm_two_factor_authenticated

    def show
      analytics.idv_phone_required_visited
    end
  end
end
