module Dradis::Plugins::CSV
  class Importer < Dradis::Plugins::Upload::Importer
    REDIS_PREFIX = 'addons-csv-upload-'.freeze

    def self.templates
      {}
    end

    def import(params={})
      logger.info { 'Uploading CSV file...' }

      uid = @logger.uid

      # SEE: app/controllers/dradis/plugins/csv/upload_controller.rb
      Resque.redis.set(REDIS_PREFIX + uid.to_s, File.basename(params[:file]))

      logger.info { 'Done' }
    end

    def import_csv(params)
      logger.info { 'Worker process starting background task.' }

      mappings_groups = params[:mappings].group_by { |index, mapping| mapping['type'] }

      id_index = Integer(mappings_groups['identifier']&.first&.first, exception: false)
      @evidence_mappings = mappings_groups['evidence'] || []
      @issue_lookup = {}
      @issue_mappings = mappings_groups['issue'] || []
      @node_index = Integer(mappings_groups['node']&.first&.first, exception: false)

      CSV.foreach(params[:file], headers: true).with_index do |row, index|
        csv_id = row[id_index] || "#{File.basename(params[:file])}-#{index}"
        process_issue(csv_id: csv_id, row: row)
        process_node(csv_id: csv_id, row: row)
      end

      true
    end

    private

    attr_accessor :evidence_mappings, :issue_lookup, :issue_mappings, :node_index

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
