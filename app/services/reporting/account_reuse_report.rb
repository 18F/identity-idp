module Reporting
  class AccountReuseReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    # Return array of arrays
    def account_reuse_report
      account_reuse_table = []
      account_reuse_table << [
        'Metric',
        'Num. all users',
        '% of accounts',
        'Num. IDV users',
        '% of accounts',
      ]

      total_reuse_report.each do |key, entity_summary|
        entity_results = entity_summary[:results]

        entity_results[:detail_rows].each do |detail_row|
          account_reuse_table << detail_row.as_csv
        end

        account_reuse_table << entity_summary.summary_row_as_csv
      end

      account_reuse_table
    end

    def account_reuse_emailable_report
      EmailableReport.new(
        title: "IDV app reuse rate #{stats_month}",
        float_as_percent: true,
        precision: 4,
        filename: 'account_reuse',
        table: account_reuse_report,
      )
    end

    def stats_month
      report_date.prev_month(1).strftime('%b-%Y')
    end

    private

    ReuseDetailRow = Struct.new(
      :num_entities, :entity_type, :num_all_users, :all_percent, :num_idv_users,
      :idv_percent
    ) do
      def initialize(num_entities: 0, entity_type: '', num_all_users: 0, all_percent: 0,
                     num_idv_users: 0, idv_percent: 0)
        super(
          num_entities:, entity_type:, num_all_users:, all_percent:, num_idv_users:,
          idv_percent:)
      end

      def update_details(num_entities: nil, entity_type: nil, num_idv_users: nil,
                         num_all_users: nil)
        self.num_entities = num_entities if !num_entities.nil?

        self.entity_type = entity_type if !entity_type.nil?

        self.num_idv_users = num_idv_users if !num_idv_users.nil?

        self.num_all_users = num_all_users if !num_all_users.nil?

        self
      end

      def as_csv
        [
          "#{self.num_entities} #{self.entity_type}",
          self.num_all_users,
          self.all_percent,
          self.num_idv_users,
          self.idv_percent,
        ]
      end

      self
    end

    ReuseDetailSection = Struct.new(:detail_rows) do
      def initialize(detail_rows: [ReuseDetailRow.new])
        super(detail_rows:)
      end

      def organize_results(all_results, idv_results, entity_type)
        idv_results.each do |result|
          entity_num = result["num_#{entity_type}"]
          self.detail_rows[entity_num] =
            ReuseDetailRow.new.update_details(
              num_entities: entity_num,
              entity_type: entity_type,
              num_idv_users: result['num_idv_users'],
            )
        end

        all_results.each do |result|
          entity_num = result["num_#{entity_type}"]
          if self.detail_rows[entity_num].is_a?(Struct)
            self.detail_rows[entity_num].update_details(num_all_users: result['num_all_users'])
          else
            self.detail_rows[entity_num] =
              ReuseDetailRow.new.update_details(
                num_entities: entity_num,
                entity_type: entity_type,
                num_all_users: result['num_all_users'],
              )
          end
        end

        if self.detail_rows.length > 1
          # If there are results, then remove the zero placeholder
          self.detail_rows[0] = nil
          self.detail_rows = self.detail_rows.compact
        else
          # Otherwise, add the entity type to the placeholder
          self.detail_rows[0] = self.detail_rows[0].update_details(entity_type: entity_type)
        end

        self
      end

      self
    end

    EntityReuseSummary = Struct.new(
      :results, :entity_type, :total_all_users, :total_all_percent, :total_idv_users,
      :total_idv_percent
    ) do
      def initialize(entity_type: '', total_all_users: 0, total_all_percent: 0, total_idv_users: 0,
                     total_idv_percent: 0)
        super(
          entity_type:, total_all_users:, total_all_percent:, total_idv_users:,
          total_idv_percent:)
      end

      def update_from_results(results, entity_type, total_proofed)
        self.entity_type = entity_type if !entity_type.nil?

        if !results.nil? && !results[:detail_rows].nil? && !results[:detail_rows].empty?
          detail_section = results[:detail_rows]
          detail_section.each do |result_entry|
            self.total_all_users += result_entry.dig(:num_all_users)
            self.total_idv_users += result_entry.dig(:num_idv_users)
          end

          if total_proofed > 0
            # Calculate percentages for breakdowns with both sps and angencies
            detail_section.each_with_index do |result_entry, index|
              detail_section[index][:all_percent] =
                result_entry.dig(:num_all_users) / total_proofed.to_f
              detail_section[index][:idv_percent] =
                result_entry.dig(:num_idv_users) / total_proofed.to_f

              self.total_all_percent += detail_section[index].dig(:all_percent)
              self.total_idv_percent += detail_section[index].dig(:idv_percent)
            end
          end
        end
        self.results = results

        self
      end

      def summary_row_as_csv
        [
          "2+ #{self.entity_type}",
          self.total_all_users,
          self.total_all_percent,
          self.total_idv_users,
          self.total_idv_percent,
        ]
      end
    end

    def total_reuse_report
      return @total_reuse_report if defined?(@total_reuse_report)

      reuse_results = {
        sp: ReuseDetailSection.new.organize_results(
          sp_reuse_results_all, sp_reuse_results_idv,
          'apps'
        ),
        agency: ReuseDetailSection.new.organize_results(
          agency_reuse_results_all,
          agency_reuse_results_idv, 'agencies'
        ),
      }

      total_proofed = num_active_profiles

      sp_reuse_stats = EntityReuseSummary.new.update_from_results(
        reuse_results[:sp], 'apps',
        total_proofed
      )
      agency_reuse_stats = EntityReuseSummary.new.update_from_results(
        reuse_results[:agency],
        'agencies', total_proofed
      )

      @total_reuse_report = {
        sp_reuse_stats: sp_reuse_stats,
        agency_reuse_stats: agency_reuse_stats,
      }
    end

    def sp_reuse_results_all
      sp_all_sql = format(<<-SQL, params)
        SELECT
            COUNT(*) AS num_all_users
            , sps_per_all_users.num_apps
        FROM (
            SELECT
                COUNT(*) AS num_apps
                , identities.user_id
            FROM
                identities
            WHERE
                identities.verified_at < %{query_date}
            GROUP BY
                identities.user_id
        ) sps_per_all_users
        GROUP BY
            sps_per_all_users.num_apps
        HAVING 
            sps_per_all_users.num_apps > 1
        ORDER BY
            num_apps ASC
      SQL

      sp_all_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sp_all_sql)
      end

      sp_all_results.as_json
    end

    def sp_reuse_results_idv
      sp_idv_sql = format(<<-SQL, params)
        SELECT
            COUNT(*) AS num_idv_users
            , sps_per_idv_users.num_apps
        FROM (
            SELECT
                COUNT(*) AS num_apps
                , identities.user_id
            FROM
                identities
            WHERE
                identities.last_ial2_authenticated_at IS NOT NULL
            AND
                identities.verified_at < %{query_date}
            GROUP BY
                identities.user_id
        ) sps_per_idv_users
        GROUP BY
            sps_per_idv_users.num_apps
        HAVING 
            sps_per_idv_users.num_apps > 1
        ORDER BY
            num_apps ASC
      SQL

      sp_idv_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sp_idv_sql)
      end

      sp_idv_results.as_json
    end

    def agency_reuse_results_all
      agency_all_sql = format(<<-SQL, params)
      SELECT
          COUNT(*) AS num_all_users
          , agencies_per_user.num_agencies
      FROM (
          SELECT
              COUNT(DISTINCT agencies.id) AS num_agencies
              , identities.user_id
          FROM
              identities
          JOIN
              service_providers sp ON identities.service_provider = sp.issuer
          JOIN
              agencies ON sp.agency_id = agencies.id
          WHERE
              identities.verified_at < %{query_date}
          GROUP BY
              identities.user_id
      ) agencies_per_user
      GROUP BY
          agencies_per_user.num_agencies
      HAVING 
          agencies_per_user.num_agencies > 1
      ORDER BY
          num_agencies ASC
      SQL

      agency_all_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(agency_all_sql)
      end

      agency_all_results.as_json
    end

    def agency_reuse_results_idv
      agency_idv_sql = format(<<-SQL, params)
        SELECT
            COUNT(*) AS num_idv_users
            , agencies_per_user.num_agencies
        FROM (
            SELECT
                COUNT(DISTINCT agencies.id) AS num_agencies
                , identities.user_id
            FROM
                identities
            JOIN
                service_providers sp ON identities.service_provider = sp.issuer
            JOIN
                agencies ON sp.agency_id = agencies.id
            WHERE
                identities.last_ial2_authenticated_at IS NOT NULL
            AND
                identities.verified_at < %{query_date}
            GROUP BY
                identities.user_id
        ) agencies_per_user
        GROUP BY
            agencies_per_user.num_agencies
        HAVING 
            agencies_per_user.num_agencies > 1
        ORDER BY
            num_agencies ASC
      SQL

      agency_idv_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(agency_idv_sql)
      end

      agency_idv_results.as_json
    end

    def num_active_profiles
      proofed_sql = format(<<-SQL, params)
          SELECT
            COUNT(*) AS num_proofed
          FROM
            profiles
          WHERE
            profiles.active = TRUE
          AND
            profiles.activated_at < %{query_date}
      SQL

      proofed_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(proofed_sql)
      end

      proofed_results.first['num_proofed']
    end

    def params
      {
        query_date: report_date.end_of_day,
      }.transform_values { |v| ActiveRecord::Base.connection.quote(v) }
    end
  end
end
