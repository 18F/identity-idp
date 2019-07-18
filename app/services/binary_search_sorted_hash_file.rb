class BinarySearchSortedHashFile
  RECORD_SIZE = 41

  def initialize(file_name)
    @file_name = file_name
  end

  # :reek:TooManyStatements
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
