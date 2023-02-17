class TransliterableFieldComponent < BaseComponent
    attr_reader :name, :block

    def initialize(name:, &block)
        @name = name
        @block = block
    end
end