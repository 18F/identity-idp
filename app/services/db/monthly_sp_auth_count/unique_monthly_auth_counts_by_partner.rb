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