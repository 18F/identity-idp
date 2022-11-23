require 'set'

module Proofing
  class Base
    @vendor_name = nil
    @required_attributes = []
    @optional_attributes = []
    @stage = nil

    class << self
      attr_reader :proofer

      def vendor_name(name = nil)
        @vendor_name = name || @vendor_name
      end

      def required_attributes(*required_attributes)
        return @required_attributes || [] if required_attributes.empty?
        @required_attributes = required_attributes
      end

      def optional_attributes(*optional_attributes)
        return @optional_attributes || [] if optional_attributes.empty?
        @optional_attributes = optional_attributes
      end

      def attributes
        [*required_attributes, *optional_attributes]
      end

      def stage(stage = nil)
        @stage = stage || @stage
      end

      def proof(sym = nil, &block)
        @proofer = sym || block
      end
    end

    def proof(applicant)
      vendor_applicant = restrict_attributes(applicant)
      validate_attributes(vendor_applicant)
      result = Proofing::Result.new
      execute_proof(proofer, vendor_applicant, result)
      result
    rescue => exception
      NewRelic::Agent.notice_error(exception)
      Proofing::Result.new(exception: exception)
    end

    private

    def execute_proof(proofer, *args)
      if proofer.is_a? Symbol
        send(proofer, *args)
      else
        instance_exec(*args, &proofer)
      end
    end

    def restrict_attributes(applicant)
      applicant.select { |attribute| attributes.include?(attribute) }
    end

    def validate_attributes(applicant)
      empty_attributes = applicant.select { |_, attribute| blank?(attribute) }.keys
      missing_attributes = attributes - applicant.keys
      bad_attributes = (empty_attributes | missing_attributes) - optional_attributes
      raise error_message(bad_attributes) if bad_attributes.any?
    end

    def error_message(required_attributes)
      "Required attributes #{required_attributes.join(', ')} are not present"
    end

    def required_attributes
      self.class.required_attributes
    end

    def optional_attributes
      self.class.optional_attributes
    end

    def attributes
      self.class.attributes
    end

    def stage
      self.class.stage
    end

    def proofer
      self.class.proofer
    end

    def blank?(val)
      !val || val.to_s.empty?
    end
  end
end
