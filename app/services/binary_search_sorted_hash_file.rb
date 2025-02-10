# frozen_string_literal: true

class BinarySearchSortedHashFile
  include ::NewRelic::Agent::MethodTracer

  RECORD_SIZE = 41

  def initialize(file_name)
    @file_name = file_name
  end

  def call(password)
    key = Digest::SHA1.hexdigest(password).upcase
    min = 0
    max = File.size(@file_name) / RECORD_SIZE
    middle = 0
    File.open(@file_name) do |file|
      loop do
        return false if max <= min
        old_middle = middle
        middle = (max + min) / 2
        return false if middle == old_middle
        file.seek middle * RECORD_SIZE
        val = file.readline.chomp
        return true if val == key
        if file.eof? || val > key
          max = middle
        else
          min = middle
        end
      end
    end
  end

  add_method_tracer :call, "Custom/#{name}/call"
end
