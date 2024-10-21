# frozen_string_literal: true

require 'csv'
begin
  require 'reporting/cloudwatch_client'
  require 'reporting/cloudwatch_query_quoting'
  require 'reporting/command_line_options'
  require 'reporting/identity_verification_report'
rescue LoadError => e
  warn 'could not load paths, try running with "bundle exec rails runner"'
  raise e
end

module Reporting
  class DropOffReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :issuers, :time_range

    def initialize(
      issuers:,
      time_range:,
      verbose: false,
      progress: false,
      slice: 3.hours,
      threads: 5
    )
      @issuers = issuers
      @time_range = time_range
      @verbose = verbose
      @progress = progress
      @slice = slice
      @threads = threads
    end

    module Events
      IDV_DOC_AUTH_WELCOME = 'IdV: doc auth welcome visited'
      IDV_DOC_AUTH_WELCOME_SUBMITTED = 'IdV: doc auth welcome submitted'
      IDV_DOC_AUTH_IMAGE_UPLOAD = 'IdV: doc auth image upload vendor submitted'
      IDV_DOC_AUTH_CAPTURED = 'IdV: doc auth document_capture visited'
      IDV_DOC_AUTH_SSN_VISITED = 'IdV: doc auth ssn visited'
      IDV_DOC_AUTH_VERIFY_VISITED = 'IdV: doc auth verify visited'
      IDV_DOC_AUTH_VERIFY_SUBMITTED = 'IdV: doc auth verify submitted'
      IDV_DOC_AUTH_PHONE_VISITED = 'IdV: phone of record visited'
      IDV_ENTER_PASSWORD_VISITED = 'idv_enter_password_visited'
      OLD_IDV_ENTER_PASSWORD_VISITED = 'IdV: review info visited'
      IDV_PENDING_GPO = 'IdV: USPS address letter enqueued'
      IDV_ENTER_PASSWORD_SUBMITTED = 'idv_enter_password_submitted'
      OLD_IDV_ENTER_PASSWORD_SUBMITTED = 'IdV: review complete'
      IDV_FINAL_RESOLUTION = 'IdV: final resolution'
      IPP_ENROLLMENT_UPDATE = 'GetUspsProofingResultsJob: Enrollment status updated'

      def self.all_events
        constants.map { |c| const_get(c) }
      end

      def self.must_pass_events
        [IPP_ENROLLMENT_UPDATE]
      end
    end

    module Results
      IDV_FINAL_RESOLUTION_VERIFIED = 'IdV: final resolution - Verified'
    end

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: 'Step Definitions',
          table: STEP_DEFINITIONS,
        ),
        Reporting::EmailableReport.new(
          title: 'Overview',
          table: overview_table,
        ),
        Reporting::EmailableReport.new(
          title: 'DropOff Metrics',
          table: dropoff_metrics_table,
          float_as_percent: true,
        ),
      ]
    end

    def overview_table
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        # This needs to be Date.today so it works when run on the command line
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', Array(issuers).join(', ')],
      ]
    end

    def dropoff_metrics_table
      [
        ['Step', 'Unique user count', 'Users lost', 'Dropoff from last step',
         'Users left from start'],
        [
          'Welcome (page viewed)',
          idv_started,
        ],
        [
          'User agreement (page viewed)',
          idv_doc_auth_welcome_submitted,
          dropoff = idv_started - idv_doc_auth_welcome_submitted,
          percent(
            numerator: dropoff,
            denominator: idv_started,
          ),
          percent(numerator: idv_doc_auth_welcome_submitted, denominator: idv_started),
        ],
        [
          'Capture Document (page viewed)',
          idv_doc_auth_document_captured,
          dropoff = idv_doc_auth_welcome_submitted -
                    idv_doc_auth_document_captured,
          percent(
            numerator: dropoff,
            denominator: idv_doc_auth_welcome_submitted,
          ),
          percent(
            numerator: idv_doc_auth_document_captured,
            denominator: idv_started,
          ),
        ],
        [
          'Document submitted (event)',
          idv_doc_auth_image_vendor_submitted,
          dropoff = idv_doc_auth_document_captured -
                    idv_doc_auth_image_vendor_submitted,
          percent(
            numerator: dropoff,
            denominator: idv_doc_auth_document_captured,
          ),
          percent(
            numerator: idv_doc_auth_image_vendor_submitted,
            denominator: idv_started,
          ),
        ],
        [
          'SSN (page view)',
          idv_doc_auth_ssn_visited,
          dropoff = idv_doc_auth_image_vendor_submitted -
                    idv_doc_auth_ssn_visited,
          percent(
            numerator: dropoff,
            denominator: idv_doc_auth_image_vendor_submitted,
          ),
          percent(
            numerator: idv_doc_auth_ssn_visited,
            denominator: idv_started,
          ),
        ],
        [
          'Verify Info (page view)',
          idv_doc_auth_verify_visited,
          dropoff = idv_doc_auth_ssn_visited -
                    idv_doc_auth_verify_visited,
          percent(
            numerator: dropoff,
            denominator: idv_doc_auth_ssn_visited,
          ),
          percent(
            numerator: idv_doc_auth_verify_visited,
            denominator: idv_started,
          ),
        ],
        [
          'Verify submit (event)',
          idv_doc_auth_verify_submitted,
          dropoff = idv_doc_auth_verify_visited -
                    idv_doc_auth_verify_submitted,
          percent(
            numerator: dropoff,
            denominator: idv_doc_auth_verify_visited,
          ),
          percent(
            numerator: idv_doc_auth_verify_submitted,
            denominator: idv_started,
          ),
        ],
        [
          'Phone finder (page view)',
          idv_doc_auth_phone_visited,
          dropoff = idv_doc_auth_verify_submitted -
                    idv_doc_auth_phone_visited,
          percent(
            numerator: dropoff,
            denominator: idv_doc_auth_verify_submitted,
          ),
          percent(
            numerator: idv_doc_auth_phone_visited,
            denominator: idv_started,
          ),
        ],
        [
          'Encrypt account: enter password (page view)',
          idv_enter_password_visited,
          dropoff = idv_doc_auth_phone_visited -
                    idv_enter_password_visited,
          percent(
            numerator: dropoff,
            denominator: idv_doc_auth_phone_visited,
          ),
          percent(
            numerator: idv_enter_password_visited,
            denominator: idv_started,
          ),
        ],
        [
          'Personal key input (page view)',
          idv_enter_password_submitted,
          dropoff = idv_enter_password_visited -
                    idv_enter_password_submitted,
          percent(
            numerator: dropoff,
            denominator: idv_enter_password_visited,
          ),
          percent(
            numerator: idv_enter_password_submitted,
            denominator: idv_started,
          ),
        ],
        [
          'Verified (event)',
          idv_final_resolution_verified,
          dropoff = idv_enter_password_submitted -
                    idv_final_resolution_verified,
          percent(
            numerator: dropoff,
            denominator: idv_enter_password_submitted,
          ),
          percent(
            numerator: idv_final_resolution_verified,
            denominator: idv_started,
          ),
        ],
        [
          'Workflow Complete - Total Pending',
          idv_final_resolution_total_pending,
        ],
        [
          'Successfully verified via in-person proofing',
          ipp_verification_total,
        ],
      ]
    end

    def idv_final_resolution_total_pending
      @idv_final_resolution_total_pending ||=
        (data[Events::IDV_FINAL_RESOLUTION] - data[Results::IDV_FINAL_RESOLUTION_VERIFIED]).count
    end

    def idv_final_resolution_verified
      data[Results::IDV_FINAL_RESOLUTION_VERIFIED].count
    end

    def ipp_verification_total
      @ipp_verification_total ||= data[Events::IPP_ENROLLMENT_UPDATE].count
    end

    STEP_DEFINITIONS = [
      ['Step', 'Definition'],
      [
        'Welcome (page view)',
        'Start of proofing process',
      ],
      [
        'User agreement (page view)',
        'Users who clicked "Continue" on the welcome page',
      ],
      [
        'Capture Document (page view)',
        'Users who check the consent checkbox and click "Continue"',
      ],
      [
        'Document submitted (event)',
        'Users who upload a front and back image and click "Submit"	',
      ],
      [
        'SSN (page view)',
        'Users whose ID is authenticated by Acuant',
      ],
      [
        'Verify Info (page view)',
        'Users who enter an SSN and continue',
      ],
      [
        'Verify submit (event)',
        'Users who verify their information and submit it for Identity Verification (LN)',
      ],
      [
        'Phone finder (page view)',
        'Users who successfuly had their identities verified by LN',
      ],
      [
        'Encrypt account: enter password (page view)',
        'Users who were able to complete the physicality check using PhoneFinder',
      ],
      [
        'Personal key input (page view)',
        'Users who enter their password to encrypt their PII',
      ],
      [
        'Verified (event)',
        'Users who completed identity verification in a single, unsupervised session',
      ],
      [
        'Workflow Complete - Total Pending',
        'Total count of users who are pending IDV',
      ],
      [
        'Successfully verified via in-person proofing',
        'The count of users who successfully verified their identity in-person at a USPS location within the report period', # rubocop:disable Layout/LineLength
      ],
    ].freeze

    def idv_started
      data[Events::IDV_DOC_AUTH_WELCOME].count
    end

    def idv_doc_auth_welcome_submitted
      data[Events::IDV_DOC_AUTH_WELCOME_SUBMITTED].count
    end

    def idv_doc_auth_document_captured
      data[Events::IDV_DOC_AUTH_CAPTURED].count
    end

    def idv_doc_auth_image_vendor_submitted
      data[Events::IDV_DOC_AUTH_IMAGE_UPLOAD].count
    end

    def idv_doc_auth_ssn_visited
      data[Events::IDV_DOC_AUTH_SSN_VISITED].count
    end

    def idv_doc_auth_verify_visited
      data[Events::IDV_DOC_AUTH_VERIFY_VISITED].count
    end

    def idv_doc_auth_verify_submitted
      data[Events::IDV_DOC_AUTH_VERIFY_SUBMITTED].count
    end

    def idv_doc_auth_phone_visited
      data[Events::IDV_DOC_AUTH_PHONE_VISITED].count
    end

    def idv_enter_password_visited
      (data[Events::IDV_ENTER_PASSWORD_VISITED] +
        data[Events::OLD_IDV_ENTER_PASSWORD_VISITED]).count
    end

    def idv_enter_password_submitted
      (data[Events::IDV_ENTER_PASSWORD_SUBMITTED] +
        data[Events::OLD_IDV_ENTER_PASSWORD_SUBMITTED]).count
    end

    def idv_pending_gpo
      data[Events::IDV_PENDING_GPO].count
    end

    def as_tables
      [
        STEP_DEFINITIONS,
        overview_table,
        dropoff_metrics_table,
      ]
    end

    def to_csvs
      as_tables.map do |table|
        CSV.generate do |csv|
          table.each do |row|
            csv << row
          end
        end
      end
    end

    # @return [Float]
    def percent(numerator:, denominator:)
      result = (numerator.to_f / denominator.to_f)
      result.nan? ? 0 : result
    end

    def fetch_results(query: nil)
      query ||= self.query
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        issuers: issuers.present? && quote(issuers),
        event_names: quote(Events.all_events),
        must_pass_event_names: quote(Events.must_pass_events),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id AS user_id
          , coalesce(properties.event_properties.success, properties.event_properties.passed, 0) AS success
          , coalesce(properties.event_properties.fraud_review_pending, 0) AS fraud_review_pending
          , coalesce(properties.event_properties.gpo_verification_pending, 0) AS gpo_verification_pending
          , coalesce(properties.event_properties.in_person_verification_pending, 0) AS in_person_verification_pending
          , ispresent(properties.event_properties.deactivation_reason) AS has_other_deactivation_reason
          , !fraud_review_pending and !gpo_verification_pending and !in_person_verification_pending and !has_other_deactivation_reason AS identity_verified
        | filter name in %{event_names}
        #{issuers.present? ? '| filter properties.service_provider IN %{issuers} or properties.event_properties.issuer IN %{issuers}' : ''}
        | filter (name in %{must_pass_event_names} and properties.event_properties.passed = 1) or (name not in %{must_pass_event_names})
        | limit 10000
      QUERY
    end

    # event name => set(user ids)
    # @return Hash<String,Set<String>>
    def data
      @data ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_results.each do |row|
          event = row['name']
          user_id = row['user_id']
          event_users[event] << user_id

          case event
          when Events::IDV_FINAL_RESOLUTION
            if row['identity_verified'] == '1'
              event_users[Results::IDV_FINAL_RESOLUTION_VERIFIED] << user_id
            end
          end
        end

        event_users
      end
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        num_threads: @threads,
        ensure_complete_logs: true,
        slice_interval: @slice,
        progress: false,
        logger: nil,
      )
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV, require_issuer: false)

  Reporting::DropOffReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end
