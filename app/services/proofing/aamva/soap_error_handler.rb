# frozen_string_literal: true

require 'rexml/document'
require 'rexml/xpath'

module Proofing
  module Aamva
    class SoapErrorHandler
      attr_reader :error_message

      def initialize(http_response)
        @document = REXML::Document.new(http_response.body)
        parse_error_message
      rescue REXML::ParseException => e
        @error_present = true
        @error_message = e.to_s
      end

      def error_present?
        @error_present
      end

      private

      attr_reader :document

      def add_program_exception_messages
        return if program_exception_nodes.empty?
        @error_message += ' - ' + program_exception_nodes.map do |exception_node|
          program_exception_message_for_exception_node(exception_node)
        end.join(' ; ')
      end

      def parse_error_message
        @error_present = !soap_fault_node.nil?
        return unless error_present?
        @error_message = soap_error_reason_text_node&.text || 'A SOAP error occurred'
        add_program_exception_messages
      end

      def program_exception_message_for_exception_node(exception_node)
        exception_node.children.map do |child|
          next unless child.node_type == :element
          "#{child.name}: #{child.text}"
        end.compact.join(', ')
      end

      def program_exception_nodes
        @program_exception_nodes ||=
          REXML::XPath.match(document, '//ProgramExceptions/ProgramException')
      end

      def soap_error_reason_text_node
        REXML::XPath.first(
          document,
          '//soap-envelope:Reason/soap-envelope:Text',
          'soap-envelope' => 'http://www.w3.org/2003/05/soap-envelope',
        )
      end

      def soap_fault_node
        REXML::XPath.first(
          document,
          '//soap-envelope:Fault',
          'soap-envelope' => 'http://www.w3.org/2003/05/soap-envelope',
        )
      end
    end
  end
end
