module Dradis::Plugins::CSV
  class Importer < Dradis::Plugins::Upload::Importer
    # Sources are dynamic (one per mapped CSV format), so report the
    # currently known sources grouped by entity for the Mappings Manager.
    def self.templates
      sources = Dradis::Plugins::CSV.mapping_sources.map(&:to_s)

      {
        evidence: sources.grep(/_evidence\z/),
        issue: sources.grep(/_issue\z/)
      }
    end

    # Imports a CSV file using a Mapping previously saved through the column
    # mapper (see MappingBuilder).
    def import(params = {})
      file = params[:file]
      filename = File.basename(file)

      headers = ::CSV.open(file, &:readline)

      issue_source = Dradis::Plugins::CSV.mapping_source(headers: headers, entity: :issue)
      evidence_source = Dradis::Plugins::CSV.mapping_source(headers: headers, entity: :evidence)

      issue_fields = stored_mapping_fields(issue_source)
      evidence_fields = stored_mapping_fields(evidence_source)

      if issue_fields.empty? && evidence_fields.empty?
        error = 'No saved mapping matches this CSV format. Re-upload the '\
                'file and use the column mapper to create one.'
        logger.fatal { error }
        return false
      end

      id_field = issue_fields.find { |field| field.destination_field == Mapping::IDENTIFIER_FIELD }
      node_field = evidence_fields.find { |field| field.destination_field == Mapping::NODE_LABEL_FIELD }

      issue_content_fields = issue_fields - [id_field].compact
      evidence_content_fields = evidence_fields - [node_field].compact

      logger.info { 'Applying saved mapping to CSV file...' }

      ::CSV.foreach(file, headers: true).with_index do |row, index|
        field_processor = FieldProcessor.new(data: row)

        csv_id = id_field && field_processor.value(field: id_field.source_field)
        csv_id = "#{filename}-#{index}" if csv_id.blank?

        logger.info { "\t => Creating new issue (plugin_id: #{csv_id})" }
        issue_text =
          if issue_content_fields.any?
            mapping_service.apply_mapping(
              source: issue_source, data: row, mapping_fields: issue_content_fields
            )
          else
            ''
          end
        issue = content_service.create_issue(text: issue_text, id: csv_id)

        node_label = node_field && field_processor.value(field: node_field.source_field)
        next if node_label.blank?

        logger.info { "\t\t => Creating evidence: (node: #{node_label}, plugin_id: #{csv_id})" }
        node = content_service.create_node(label: node_label, type: :host)
        evidence_content =
          if evidence_content_fields.any?
            mapping_service.apply_mapping(
              source: evidence_source, data: row, mapping_fields: evidence_content_fields
            )
          else
            ''
          end
        content_service.create_evidence(issue: issue, node: node, content: evidence_content)
      end

      logger.info { 'Done.' }
      true
    end

    def import_csv(params)
      logger.info { 'Worker process starting background task.' }

      mappings_groups = params[:mappings].group_by { |index, mapping| mapping['type'] }

      filename = File.basename(params[:file])
      id_index = Integer(mappings_groups['identifier']&.first&.first, exception: false)
      @evidence_mappings = mappings_groups['evidence'] || []
      @issue_lookup = {}
      @issue_mappings = mappings_groups['issue'] || []
      @node_index = Integer(mappings_groups['node']&.first&.first, exception: false)


      CSV.foreach(params[:file], headers: true).with_index do |row, index|
        csv_id = row[id_index] || "#{filename}-#{index}"
        process_issue(csv_id: csv_id, row: row)
        process_node(csv_id: csv_id, row: row)
      end

      true
    end

    private

    attr_accessor :evidence_mappings, :issue_lookup, :issue_mappings, :node_index

    def stored_mapping_fields(source)
      mapping = Dradis::Plugins::CSV.get_mapping(
        source: source,
        destination: mapping_service.destination
      )

      mapping ? mapping.mapping_fields.to_a : []
    end

    def build_text(mappings:, row:)
      mappings.map do |index, mapping|
        next if project.report_template_properties && mapping['field'].blank?

        field_name = project.report_template_properties ? mapping['field'] : row.headers[index.to_i].delete(" \t\r\n")
        field_value = row[index.to_i]
        "#[#{field_name}]#\n#{field_value}"
      end.compact.join("\n\n")
    end

    def process_evidence(csv_id:, node:, row:)
      logger.info{ "\t\t => Creating evidence: (node: #{node.label}, plugin_id: #{csv_id})" }

      issue = issue_lookup[csv_id]
      evidence_content = build_text(mappings: @evidence_mappings, row: row)
      content_service.create_evidence(issue: issue, node: node, content: evidence_content)
    end

    def process_issue(csv_id:, row:)
      logger.info { "\t => Creating new issue (plugin_id: #{csv_id})" }
      issue_text = build_text(mappings: issue_mappings, row: row)
      issue = content_service.create_issue(text: issue_text, id: csv_id)

      issue_lookup[csv_id] = issue
    end

    def process_node(csv_id:, row:)
      node_label = row[node_index]

      if node_label.present?
        logger.info { "\t\t => Processing node: #{node_label}" }
        node = content_service.create_node(label: node_label, type: :host)

        process_evidence(csv_id: csv_id, node: node, row: row)
      end
    end
  end
end
