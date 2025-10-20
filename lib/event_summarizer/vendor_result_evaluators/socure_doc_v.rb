# frozen_string_literal: true

require 'byebug'

module EventSummarizer
  module VendorResultEvaluators
    class SocureDocV
      # @param result {Hash} The array of processed_alerts.failed logged to Cloudwatch
      # @option result [Boolean] :success Whether the Socure DocV check was successful
      # @option result [String] :document_type The type of document processed
      # @option result [Array<String>] :reason_codes The array of reason codes returned by Socure
      #
      # @return [Hash] A Hash with a type and description keys.
      def self.evaluate_result(result)
        return if result[:success] == true

        alerts = []
        result[:reason_codes]&.each do |code|
          if code[0] == 'R'
            alerts << {
              type: code,
              description: "#{code}: #{reason_code_description(code)}",
            }
          end
        end

        alerts.uniq! { |a| a[:description] }
        bullet = "#{' ' * 17}- "
        description = "Socure DocV request failed (document_type: #{result[:document_type]}):"
        if !alerts.empty?
          description += "\n#{bullet}#{alerts.map { |a| a[:description] }.join("\n#{bullet}")}"
        end
        return {
          type: :socure_docv_failures,
          description:,
        }
      end

      def self.reason_code_description(code)
        REASON_CODES[code]
      end

      # This list includes all the R8xx reason codes as of 10/3/2025
      # Easier to maintain here than in the DB
      REASON_CODES = {
        'R810' =>	'Document pattern and layout integrity check failed',
        'R819' =>	'Document fails liveness check',
        'R820' =>	'Document headshot has been modified',
        'R822' =>	'First name extracted from document does not match input first name',
        'R823' =>	'Last name extracted from document does not match input last name',
        'R824' =>	'Address extracted from document does not match input address',
        'R825' =>	'DOB extracted from document does not match input DOB',
        'R826' =>	'Document Number extracted from document does not match input number',
        'R827' =>	'Document is expired',
        'R831' =>	'Cannot extract the minimum information from barcode',
        'R833' =>	'Cannot extract the minimum required information from MRZ',
        'R834' =>	'Selfie fails the liveness check',
        'R836' =>	'Document image does not correlate with self-portrait',
        'R838' =>	'Minimum amount of information cannot be extracted from document',
        'R845' =>	'Minimum age criteria not met',
        'R850' =>	'Self-portrait or the headshot is not usable for Facial Match',
        'R853' =>	'Unable to classify the ID or this is an unsupported ID type',
        'R856' =>	'Obstructions on the face affecting the liveness',
        'R857' =>	'No face found in the selfie frame',
        'R858' =>	'The age on the document doesn\'t correlate with the selfie predicted age',
        'R859' =>	'ID image correlates to another ID image',
        'R861' =>	'Data extracted from document does not match with barcode or MRZ',
        'R862' =>	'The document could not be classified',
        'R863' =>	'Incorrect side of document uploaded',
        'R864' =>	'Image upload from file detected',
        'R865' =>	'Disallowed ID Type',
        'R895' =>	'First Name extracted from document was fuzzy matched with input First Name',
        'R896' =>	'Last Name extracted from document was fuzzy matched with input Last Name',
        'R897' =>	'DOB extracted from document was fuzzy matched with input DOB',
      }.freeze
    end
  end
end
