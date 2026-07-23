module Dradis::Plugins::CSV
  # Converts between the column mapper's form structure and persisted
  # Mapping records, one per entity (issue/evidence), so a CSV format only
  # needs to be mapped once: #save is the forward direction (form ->
  # records), used the first time a format is mapped. .selections_for is
  # the reverse (records -> form), used by Importer#import to recognize and
  # auto-import a format on later uploads.
  class MappingBuilder
    # Mapper column types that produce fields for each entity: identifier
    # columns are stored with the issue mapping, node columns with evidence.
    ENTITY_TYPES = {
      issue: %w[issue identifier],
      evidence: %w[evidence node]
    }.freeze

    # Inverts the stored mapping fields back into the mapper form structure:
    # one { type:, field: } entry per header, in header order.
    def self.selections_for(headers:, destination:)
      stored_fields = ENTITY_TYPES.keys.flat_map do |entity|
        source = Dradis::Plugins::CSV.mapping_source(headers: headers, entity: entity)
        mapping = Dradis::Plugins::CSV.get_mapping(source: source, destination: destination)

        mapping ? mapping.mapping_fields.map { |field| [entity, field] } : []
      end

      headers.map do |header|
        normalized = Dradis::Plugins::CSV.normalize_header(header)
        entity, field = stored_fields.find { |_entity, f| f.source_field == normalized }

        case field&.destination_field
        when nil
          { type: 'skip' }
        when Mapping::IDENTIFIER_FIELD
          { type: 'identifier' }
        when Mapping::NODE_LABEL_FIELD
          { type: 'node' }
        else
          { type: entity.to_s, field: field.destination_field }
        end
      end
    end

    attr_reader :column_mappings, :destination, :headers, :rtp_fields

    # column_mappings is the mapper form submission, keyed by column index:
    #   {
    #     '0' => { 'type' => 'node' },
    #     '1' => { 'type' => 'issue', 'field' => 'Title' },
    #     '2' => { 'type' => 'identifier' },
    #     '3' => { 'type' => 'evidence', 'field' => 'Port' }
    #   }
    # rtp_fields is { issue: [...field names...], evidence: [...] }: the
    # destination fields actually defined on the RTP, used to gate #save (see
    # below).
    def initialize(column_mappings:, destination:, headers:, rtp_fields:)
      @column_mappings = column_mappings
      @destination = destination
      @headers = headers
      @rtp_fields = rtp_fields
    end

    # Persists one Mapping per entity that has assigned columns, so a
    # newly-mapped CSV format is recognized automatically on future uploads
    # (see Importer#import). Only ever called for formats with no existing
    # mapping: Importer#import and UploadController#new short-circuit before
    # the mapper is reached once a format already has a saved mapping.
    #
    # An entity with no RTP fields defined has nowhere valid to point a
    # mapping, so it's skipped entirely (including its identifier/node
    # column, if any) rather than saving a mapping with a bogus destination.
    def save
      return if destination.blank?

      ::Mapping.transaction do
        ENTITY_TYPES.keys.each do |entity|
          next if rtp_fields[entity].blank?

          fields = fields_for(entity)
          next if fields.empty?

          source = Dradis::Plugins::CSV.mapping_source(headers: headers, entity: entity)
          mapping = ::Mapping.create!(component: component, source: source, destination: destination)
          mapping.mapping_fields.create!(fields)
        end
      end
    end

    private

    def component
      Dradis::Plugins::CSV.component
    end

    def fields_for(entity)
      types = ENTITY_TYPES.fetch(entity)

      column_mappings.filter_map do |index, assignment|
        next unless types.include?(assignment['type'])

        header = Dradis::Plugins::CSV.normalize_header(headers[index.to_i])
        next if header.blank?

        destination_field =
          case assignment['type']
          when 'identifier'
            Mapping::IDENTIFIER_FIELD
          when 'node'
            Mapping::NODE_LABEL_FIELD
          else
            field = assignment['field'] == 'Custom Field' ? assignment['custom_field'] : assignment['field']
            next if field.blank?

            field
          end

        {
          source_field: header,
          content: "{{ csv[#{header}] }}",
          destination_field: destination_field
        }
      end
    end
  end
end
