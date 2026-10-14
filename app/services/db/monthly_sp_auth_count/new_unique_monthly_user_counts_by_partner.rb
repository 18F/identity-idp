# frozen_string_literal: true

module Db
  module MonthlySpAuthCount
    module NewUniqueMonthlyUserCountsByPartner
      extend Reports::QueryHelpers

      # One key per user, profile and proofing age for the month. How the person reached the
      # agency (a direct sign-in, a delegated token exchange, or both) is deliberately not part
      # of the key: a person with a direct row and a delegated row at one agency in a month is
      # one billed user event, and a person seen directly in one month is not new again when they
      # arrive by delegation later. The delegated facts are tallied alongside, per key.
      UserVerifiedKey = Data.define(
        :user_id, :profile_id, :profile_age, :is_upfront
      ).freeze

      # What the month's rows say about how the person behind one key arrived: which access
      # types were seen, and whether a delegated row's approval records that the person verified
      # identity during the delegating service provider's sign-in.
      DelegationFacts = Struct.new(:access_types, :delegated_proofing) do
        def self.empty
          new(Set.new, false)
        end

        # Only delegated rows, never a direct sign-in, this month.
        def delegated_only?
          access_types == Set[SpReturnLog::ACCESS_TYPE_DELEGATED]
        end
      end

      module_function

      # @param [String] partner label for billing (Partner requesting agency)
      # @param [Array<String>] issuers issuers for the iaa
      # @param [Date] start_date iaa start date
      # @param [Date] end_date iaa end date
      # @return [PG::Result, Array]
      def call(partner:, issuers:, start_date:, end_date:)
        date_range = start_date...end_date if start_date.present? && end_date.present?

        return [] if !date_range || issuers.blank?

        # Query a month at a time, to keep query time/result size fairly reasonable
        months = Reports::MonthHelper.months(date_range)
        queries = build_queries(issuers: issuers, months: months)

        year_month_to_users_to_profile_age = Hash.new do |ym_h, ym_k|
          ym_h[ym_k] = {}
        end
        # year_month => key => DelegationFacts
        year_month_to_delegation_facts = Hash.new do |ym_h, ym_k|
          ym_h[ym_k] = Hash.new { |k_h, k| k_h[k] = DelegationFacts.empty }
        end

        # rubocop:disable Metrics/BlockLength
        queries.each do |query|
          temp_copy = year_month_to_users_to_profile_age.deep_dup
          facts_temp_copy = year_month_to_delegation_facts.deep_dup

          with_retries(
            max_tries: 3,
            rescue: [
              ActiveRecord::SerializationFailure,
              PG::ConnectionBad,
              PG::TRSerializationFailure,
              PG::UnableToSend,
            ],
            handler: proc do
              year_month_to_users_to_profile_age = temp_copy
              year_month_to_delegation_facts = facts_temp_copy
              ActiveRecord::Base.connection.reconnect!
            end,
          ) do
            Reports::BaseReport.transaction_with_timeout do
              ActiveRecord::Base.connection.execute(query).each do |row|
                year_month = row['year_month']
                profile_age = row['profile_age']
                user_id = row['user_id']
                profile_id = row['profile_id']
                profile_requested_issuer = row['profile_requested_issuer']
                issuer = row['issuer']
                access_type = row['access_type'] || SpReturnLog::ACCESS_TYPE_DIRECT
                delegated_proofing = ActiveModel::Type::Boolean.new.cast(row['delegated_proofing'])

                is_upfront = profile_requested_issuer == issuer

                user_unique_id = UserVerifiedKey.new(
                  user_id:,
                  profile_id:,
                  profile_age:,
                  is_upfront:,
                )

                year_month_to_users_to_profile_age[year_month][user_unique_id] = profile_age
                # The query returns one row per (user, ..., access type, delegated proofing), so
                # a person with both kinds of row contributes twice here and once to the key.
                facts = year_month_to_delegation_facts[year_month][user_unique_id]
                facts.access_types << access_type
                facts.delegated_proofing ||= delegated_proofing
              end
            end
          end
        end
        # rubocop:enable Metrics/BlockLength
        rows = []

        prev_seen_user_proofed_events = Set.new
        issuers_set = issuers.to_set
        year_months = year_month_to_users_to_profile_age.keys.sort

        # rubocop:disable Metrics/BlockLength
        year_months.each do |year_month|
          users_to_profile_age = year_month_to_users_to_profile_age[year_month]
          facts_by_key = year_month_to_delegation_facts[year_month]

          this_month_user_proofed_events = users_to_profile_age.keys.to_set
          new_unique_user_proofed_events = this_month_user_proofed_events -
                                           prev_seen_user_proofed_events

          # Of this month's user events, those that arrived only by delegation, and those where
          # the person verified identity during the delegating service provider's sign-in.
          delegated_only_events = this_month_user_proofed_events.select do |key|
            facts_by_key[key].delegated_only?
          end
          delegated_proofing_events = this_month_user_proofed_events.select do |key|
            facts_by_key[key].delegated_proofing
          end

          unique_profiles_by_age = bucket_by_profile_age(this_month_user_proofed_events)
          new_unique_profiles_by_age = bucket_by_profile_age(new_unique_user_proofed_events)
          new_unique_profiles_year1 = bucket_by_upfront_existing(
            new_unique_user_proofed_events, facts_by_key
          )

          prev_seen_user_proofed_events |= this_month_user_proofed_events

          rows << {
            partner: partner,
            issuers: issuers_set,
            year_month: year_month,
            iaa_start_date: date_range.begin.to_s,
            iaa_end_date: date_range.end.to_s,
            unique_user_proofed_events: this_month_user_proofed_events.count,
            partner_ial2_unique_user_events_year1: unique_profiles_by_age[0].count,
            partner_ial2_unique_user_events_year2: unique_profiles_by_age[1].count,
            partner_ial2_unique_user_events_year3: unique_profiles_by_age[2].count,
            partner_ial2_unique_user_events_year4: unique_profiles_by_age[3].count,
            partner_ial2_unique_user_events_year5: unique_profiles_by_age[4].count,
            partner_ial2_unique_user_events_year_greater_than_5: unique_profiles_by_age[:older].count, # rubocop:disable Layout/LineLength
            partner_ial2_unique_user_events_unknown: unique_profiles_by_age[:unknown].count,
            new_unique_user_proofed_events: new_unique_user_proofed_events.count,
            partner_ial2_new_unique_user_events_year1_upfront: new_unique_profiles_year1[:upfront].count, # rubocop:disable Layout/LineLength
            partner_ial2_new_unique_user_events_year1_existing: new_unique_profiles_year1[:existing].count, # rubocop:disable Layout/LineLength
            partner_ial2_new_unique_user_events_year1: new_unique_profiles_by_age[0].count,
            partner_ial2_new_unique_user_events_year2: new_unique_profiles_by_age[1].count,
            partner_ial2_new_unique_user_events_year3: new_unique_profiles_by_age[2].count,
            partner_ial2_new_unique_user_events_year4: new_unique_profiles_by_age[3].count,
            partner_ial2_new_unique_user_events_year5: new_unique_profiles_by_age[4].count,
            partner_ial2_new_unique_user_events_year_greater_than_5: new_unique_profiles_by_age[:older].count, # rubocop:disable Layout/LineLength
            partner_ial2_new_unique_user_events_unknown: new_unique_profiles_by_age[:unknown].count,
            partner_ial2_unique_user_events_delegated_only: delegated_only_events.count,
            partner_ial2_unique_user_events_delegated_proofing: delegated_proofing_events.count,
          }
        end
        # rubocop:enable Metrics/BlockLength
        rows
      end

      # @param [Array<String>] issuers all the issuers for this iaa
      # @param [Array<Range<Date>>] months ranges of dates by month that are included in this iaa,
      #  the first and last may be partial months
      # @return [Array<String>]
      #
      # Delegated rows are selected with the direct rows. A sign-in row a later exchange excluded
      # from billing is left out, as in every invoice query. `access_type` and
      # `delegated_proofing` are selected and grouped so the facts can be tallied per person;
      # they are not part of the per-person key built from the result.
      def build_queries(issuers:, months:)
        months.map do |month_range| # rubocop:disable Metrics/BlockLength
          params = {
            range_start: month_range.begin,
            range_end: month_range.end,
            year_month: month_range.begin.strftime('%Y%m'),
            issuers: issuers,
            direct: SpReturnLog::ACCESS_TYPE_DIRECT,
          }.transform_values { |value| quote(value) }

          format(<<~SQL, params)
            SELECT
              subq.user_id AS user_id
            , %{year_month} AS year_month
            , subq.profile_id AS profile_id
            , subq.profile_age AS profile_age
            , subq.profile_requested_issuer AS profile_requested_issuer
            , subq.issuer AS issuer
            , subq.access_type AS access_type
            , subq.delegated_proofing AS delegated_proofing
            FROM (
              SELECT
                  sp_return_logs.user_id
                , sp_return_logs.profile_id
                , DATE_PART('year', AGE(sp_return_logs.returned_at, sp_return_logs.profile_verified_at)) AS profile_age
                , sp_return_logs.profile_requested_issuer
                , sp_return_logs.issuer
                , COALESCE(sp_return_logs.access_type, %{direct}) AS access_type
                , #{SpReturnLogBillingAdjustment.proofed_in_session_sql} AS delegated_proofing
              FROM sp_return_logs
              WHERE
                    sp_return_logs.ial > 1
                AND sp_return_logs.returned_at::date BETWEEN %{range_start} AND %{range_end}
                AND sp_return_logs.issuer IN %{issuers}
                AND sp_return_logs.billable = true
                AND #{SpReturnLogBillingAdjustment.not_excluded_sql}
            ) subq
            GROUP BY
              subq.user_id
              , subq.profile_id
              , subq.profile_age
              , subq.profile_requested_issuer
              , subq.issuer
              , subq.access_type
              , subq.delegated_proofing
          SQL
        end
      end

      def bucket_by_profile_age(unique_user_events)
        unique_user_events.group_by do |user_unique_id|
          age = user_unique_id.profile_age
          if age.nil? || age < 0
            :unknown
          elsif age > 4
            :older
          else
            age.to_i
          end
        end.tap { |counts| counts.default = [] }
      end

      # Splits first-year events into those whose proofing this partner pays for up front and
      # those for an existing profile. A profile requested by one of the partner's own issuers is
      # upfront. A person who verified identity during a delegating service provider's sign-in
      # and was then delegated to this partner's agency is also upfront for it: the agency
      # receiving the delegated token is billed for that verification, even though the profile
      # names the service provider as the requesting issuer.
      # @param [Hash{UserVerifiedKey => DelegationFacts}] facts_by_key
      def bucket_by_upfront_existing(unique_user_events, facts_by_key = {})
        year1_events = unique_user_events.select do |user_unique_id|
          age = user_unique_id.profile_age
          !age.nil? && !age.negative? && age == 0
        end

        initially_upfront, existing = year1_events.partition do |event|
          event.is_upfront || facts_by_key[event]&.delegated_proofing
        end

        users_already_upfront = Set.new
        upfront = []

        initially_upfront.each do |event|
          if users_already_upfront.add?(event.profile_id)
            upfront << event
          else
            existing << event
          end
        end

        {
          upfront: upfront,
          existing: existing,
        }.tap { |counts| counts.default = [] }
      end
    end
  end
end
