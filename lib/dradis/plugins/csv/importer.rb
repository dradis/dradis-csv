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

    # Runs as part of the standard upload flow, before the user would reach
    # the column mapper. If this project already has a saved mapping for the
    # file's headers, import immediately using it, so a recognized format
    # never needs re-mapping and gets the same treatment (Rules Engine
    # included) as any other plugin's upload. Unrecognized formats no-op
    # here; UploadController sends the user to the mapper instead.
    def import(params = {})
      return false if destination.blank?

      headers = CSV.open(params[:file], &:readline)
      selections = MappingBuilder.selections_for(headers: headers, destination: destination)

      if selections.all? { |selection| selection[:type] == 'skip' }
        logger.info { 'No saved mapping found for this CSV format.' }
        return false
      end

      mappings = selections.each_with_index.to_h do |selection, index|
        [index.to_s, selection.transform_keys(&:to_s)]
      end

      run_import(file: params[:file], mappings: mappings)
    end

    # Entry point for the column mapper form submission (see
    # MappingImportJob), used when the CSV format has no saved mapping yet.
    def import_csv(params)
      logger.info { 'Worker process starting background task.' }

      run_import(file: params[:file], mappings: params[:mappings])
    end

    private

    attr_accessor :evidence_mappings, :issue_lookup, :issue_mappings, :node_index

    def destination
      rtp = project.report_template_properties if project

      rtp && rtp.as_mapping_destination
    end

    def run_import(file:, mappings:)
      mappings_groups = mappings.group_by { |index, mapping| mapping['type'] }

      filename = File.basename(file)
      id_index = Integer(mappings_groups['identifier']&.first&.first, exception: false)
      @evidence_mappings = mappings_groups['evidence'] || []
      @issue_lookup = {}
      @issue_mappings = mappings_groups['issue'] || []
      @node_index = Integer(mappings_groups['node']&.first&.first, exception: false)

      CSV.foreach(file, headers: true).with_index do |row, index|
        csv_id = row[id_index] || "#{filename}-#{index}"
        process_issue(csv_id: csv_id, row: row)
        process_node(csv_id: csv_id, row: row)
      end

      true
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
