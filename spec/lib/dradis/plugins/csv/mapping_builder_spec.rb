require 'rails_helper'

RSpec.describe Dradis::Plugins::CSV::MappingBuilder do
  let(:headers) { ['Id', 'Title', 'Host', 'Vulnerability Category'] }
  let(:destination) { 'rtp_1' }
  let(:column_mappings) do
    {
      '0' => { 'type' => 'identifier' },
      '1' => { 'type' => 'issue', 'field' => 'Title' },
      '2' => { 'type' => 'node', 'field' => '' },
      '3' => { 'type' => 'evidence', 'field' => 'Rating' }
    }
  end

  let(:issue_source) do
    Dradis::Plugins::CSV.mapping_source(headers: headers, entity: :issue)
  end
  let(:evidence_source) do
    Dradis::Plugins::CSV.mapping_source(headers: headers, entity: :evidence)
  end

  subject(:builder) do
    described_class.new(
      column_mappings: column_mappings,
      destination: destination,
      headers: headers
    )
  end

  describe '#save' do
    it 'creates one mapping per entity with normalized source fields' do
      expect { builder.save }.to change { Mapping.count }.by(2)

      issue_mapping = Mapping.find_by(
        component: 'csv', source: issue_source, destination: destination
      )
      expect(issue_mapping.mapping_fields.pluck(:destination_field, :source_field, :content)).to match_array([
        ['plugin_id', 'Id', '{{ csv[Id] }}'],
        ['Title', 'Title', '{{ csv[Title] }}']
      ])

      evidence_mapping = Mapping.find_by(
        component: 'csv', source: evidence_source, destination: destination
      )
      expect(evidence_mapping.mapping_fields.pluck(:destination_field, :source_field, :content)).to match_array([
        ['node_label', 'Host', '{{ csv[Host] }}'],
        ['Rating', 'VulnerabilityCategory', '{{ csv[VulnerabilityCategory] }}']
      ])
    end

    it 'does not duplicate existing mappings' do
      builder.save

      expect { builder.save }.not_to change { Mapping.count }
    end

    it 'replaces the fields of an existing mapping with the new assignments' do
      builder.save

      updated_builder = described_class.new(
        column_mappings: {
          '0' => { 'type' => 'identifier' },
          '1' => { 'type' => 'skip' }
        },
        destination: destination,
        headers: headers
      )

      expect { updated_builder.save }.to change { Mapping.count }.by(-1)

      issue_mapping = Mapping.find_by(
        component: 'csv', source: issue_source, destination: destination
      )
      expect(issue_mapping.mapping_fields.pluck(:destination_field)).to eq(['plugin_id'])
      expect(Mapping.find_by(source: evidence_source)).to be_nil
    end

    context 'without a destination' do
      let(:destination) { nil }

      it 'does not create any mappings' do
        expect { builder.save }.not_to change { Mapping.count }
      end
    end

    context 'when only skipped or blank columns are assigned to an entity' do
      let(:column_mappings) do
        {
          '0' => { 'type' => 'identifier' },
          '1' => { 'type' => 'issue', 'field' => '' },
          '3' => { 'type' => 'skip' }
        }
      end

      it 'only stores the fields with a destination' do
        expect { builder.save }.to change { Mapping.count }.by(1)

        issue_mapping = Mapping.find_by(
          component: 'csv', source: issue_source, destination: destination
        )
        expect(issue_mapping.mapping_fields.pluck(:destination_field)).to eq(['plugin_id'])
      end
    end
  end
end
