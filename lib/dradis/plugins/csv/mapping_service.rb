module Dradis::Plugins::CSV
  # CSV's source_fields/mapping_sources are database-backed (see
  # Mapping.source_fields/mapping_sources), unlike other integrations'
  # constant-backed lookups, so importing a large file would otherwise
  # trigger a query per field/entity per row. Memoized per instance: a
  # MappingService is created fresh per import run (see
  # Importer#default_mapping_service), so the cache can't outlive the data
  # it was read from.
  class MappingService < Dradis::Plugins::MappingService
    def sample
      @sample ||= {}
      @sample[source] ||=
        source_fields.index_with { |field| "Sample #{field}" }.to_json if valid_source?
    end

    private

    def source_fields
      @source_fields ||= {}
      @source_fields[source] ||= super
    end

    def valid_sources
      @valid_sources ||= super
    end
  end
end
