# frozen_string_literal: true

module Db
  module MonthlySpAuthCount
  module UniqueMonthlyAuthCountsByPartner
    extend Reports::QueryHelpers

    module_function

    # @param [String] partner label for billing
    # @param [Array<String>] issuers issuers for the partner
    # @param [Date] start_date partner start date
    # @param [Date] end_date partner end date
    # @return [PG::Result, Array]
    def call(partner:, issuers:, start_date:, end_date:)
        date_range = start_date...end_date

        return [] if !date_range || issuers.blank?

        months = Reports::MonthHelper.months(date_range)
        queries = build_queries(issuers: issuers, months: months)

        