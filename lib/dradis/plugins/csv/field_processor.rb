module Dradis::Plugins::CSV
  class FieldProcessor < Dradis::Plugins::Upload::FieldProcessor
    # data is a Hash of the current row, keyed by normalized header (see
    # Importer#normalized_row), matching how MappingForm normalizes
    # headers when it stores each field's source_field/content - except
    # when previewing a saved mapping in the Mappings Manager, where data
    # is CSV's generic empty sample (see MappingService#sample): there's no
    # real row to read then, so fall back to showing the column name being
    # referenced instead.
    def value(args = {})
      data[args[:field]]
    end
  end
end
