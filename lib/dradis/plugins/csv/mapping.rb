module Dradis::Plugins::CSV
  # Unlike other integrations, CSV files don't have a fixed structure, so the
  # list of sources can't be defined upfront. Instead, a new source is
  # registered every time a user maps a new CSV format (i.e. a new set of
  # column headers) through the column mapper (see MappingBuilder).
  #
  # The empty constants keep the interface expected by
  # Dradis::Plugins::Mappings::Base, while the class methods below override
  # its constant-backed defaults with database-backed lookups.
  module Mapping
    DEFAULT_MAPPING = {}.freeze
    SOURCE_FIELDS = {}.freeze

    # Reserved destination fields that carry row metadata instead of entity
    # content. They're stored alongside the content fields but are excluded
    # from the entity text during import.
    IDENTIFIER_FIELD = 'plugin_id'.freeze
    NODE_LABEL_FIELD = 'node_label'.freeze
  end

  def self.default_mapping(_source)
    {}
  end

  # Signals that sources are created on upload and can't be defined upfront
  # (e.g. so the Mappings Manager doesn't offer manual mapping creation).
  def self.dynamic_mapping_sources?
    true
  end

  # Excludes the reserved identifier/node fields from the destination field
  # list: they carry row metadata, not entity content (see Importer#mapped_fields,
  # which excludes them the same way when building the import template).
  def self.field_names(source:, destination: nil, field_type: 'destination')
    super.reject do |field|
      field_type == 'destination' &&
        [Mapping::IDENTIFIER_FIELD, Mapping::NODE_LABEL_FIELD].include?(field)
    end
  end

  def self.mapping_sources
    ::Mapping.where(component: component).distinct.pluck(:source).map(&:to_sym)
  end

  # The source name for a CSV format: the entity (issue/evidence) the mapping
  # populates, plus its normalized headers joined with '/', so the Mappings
  # Manager shows something recognizable (e.g. issue_severity/title) instead
  # of an opaque digest. Headers are sorted so reordering columns doesn't
  # produce a new source; any '/' inside a header name is replaced so it
  # can't be mistaken for the join separator. The entity prefix also lets
  # Importer.templates group sources by entity with a simple regex.
  def self.mapping_source(headers:, entity:)
    normalized = headers.map { |header| normalize_header(header).gsub('/', '-') }.sort

    "#{entity}_#{normalized.join('/')}"
  end

  def self.normalize_header(header)
    header.to_s.delete(" \t\r\n")
  end

  # CSV's mapping fields are never more than a direct column reference (see
  # MappingBuilder#fields_for and manage_fields.js#updateContent: content is
  # always "{{ csv[header] }}"), so there's no computed content to preview
  # against sample data, unlike other integrations. Showing which header
  # feeds which field is the whole story.
  def self.preview_mapping_fields(mapping_fields)
    mapping_fields.map do |field|
      # Extract the source field
      header = field.content[/\{\{\s?csv\[(\S*?)\]\s?\}\}/, 1] || field.content

      "#[#{field.destination_field}]#\n#{header}"
    end.join("\n\n")
  end

  def self.source_fields(source)
    ::MappingField.
      joins(:mapping).
      where(mappings: { component: component, source: source.to_s }).
      distinct.
      pluck(:source_field)
  end
end
