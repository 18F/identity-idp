# frozen_string_literal: true

module Test
  class FakeSocureConfig
    include ActiveModel::Model

    attr_accessor :success, :enabled, :selected_fixture

    validates :selected_fixture, inclusion: { in: [:pass] }, allow_nil: true

    def initialize(enabled: false, selected_fixture: nil)
      @enabled = !!enabled
      @selected_fixture = selected_fixture
    end

    # def submit
    #   @success = valid?
    #   FormResponse.new(success:, errors:)
    # end
  end
end
