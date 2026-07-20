module Dradis::Plugins::CSV
  class FieldProcessor < Dradis::Plugins::Upload::FieldProcessor
    # data is a Hash of the current row, keyed by normalized header (see
    # Importer#normalized_row), matching how MappingBuilder normalizes
    # headers when it stores each field's source_field/content.
    def value(args = {})
      data[args[:field]]
    end
  end
end
