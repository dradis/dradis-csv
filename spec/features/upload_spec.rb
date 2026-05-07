require 'rails_helper'

# To run, execute from Dradis main app folder:
#   bin/rspec [dradis-plugins path]/spec/features/upload_spec.rb

describe 'upload feature', js: true do
  before do
    login_to_project_as_user
    visit project_upload_path(@project)
  end

  context 'uploading a CSV file' do
    let(:file_path) { File.expand_path('../fixtures/files/simple.csv', __dir__) }
    before do
      @headers = CSV.open(file_path, &:readline)

      find('#state + .combobox').click
      find('#state ~ .combobox-menu .combobox-option', text: 'Published').click

      find('#uploader + .combobox').click
      find('#uploader ~ .combobox-menu .combobox-option', text: 'Dradis::Plugins::CSV').click

      attach_file 'file', file_path, visible: false, disabled: false

      expect(page).to have_text('CSV Upload Mapping', wait: 30)
    end

    it 'redirects to the mapping page' do
      expect(current_path).to eq(csv.new_project_upload_path(@project))
    end

    it 'lists the fields in the table' do
      within('tbody') do
        @headers.each do |header|
          expect(page).to have_selector('td', text: header)
        end
      end
    end

    context 'mapping CSV columns' do
      context 'when identifier not selected' do
        it 'shows a validation message on the page' do
          within all('tbody tr')[3] do
            select 'Evidence Field'
          end

          click_button 'Import CSV'
          expect(page).to have_text('An Issue ID must be selected.')
        end
      end

      context 'when there are evidence type but no node type selected' do
        it 'shows a validation message on the page' do
          within all('tbody tr')[2] do
            select 'Issue ID'
          end

          within all('tbody tr')[3] do
            select 'Evidence Field'
          end

          click_button 'Import CSV'
          expect(page).to have_text('A Node Label must be selected to import evidence records.')
        end
      end

      context 'valid states' do
        it 'imports the issues based on the selected state' do
          select 'Issue ID', from: 'mappings[field_attributes][0][type]'
          select 'Node', from: 'mappings[field_attributes][3][type]'
          select 'Evidence Field', from: 'mappings[field_attributes][4][type]'
          select 'Evidence Field', from: 'mappings[field_attributes][5][type]'

          perform_enqueued_jobs do
            click_button 'Import CSV'

            find('#console .log', wait: 30, match: :first)

            expect(page).to have_text('Worker process completed.')

            expect(Issue.published.count).to eq(1)
          end
        end
      end

      context 'invalid states' do
        it 'imports the issues as draft' do
          select 'Issue ID', from: 'mappings[field_attributes][0][type]'
          select 'Node', from: 'mappings[field_attributes][3][type]'
          select 'Evidence Field', from: 'mappings[field_attributes][4][type]'
          select 'Evidence Field', from: 'mappings[field_attributes][5][type]'

          page.execute_script(<<~JS)
            const select = document.querySelector('#state');
            select.value = 'tampered_value';
          JS

          perform_enqueued_jobs do
            click_button 'Import CSV'

            find('#console .log', wait: 30, match: :first)

            expect(page).to have_text('Worker process completed.')

            expect(Issue.published.count).to eq(0)
          end
        end
      end

      context 'when project does not have RTP' do
        it 'imports all columns as fields' do
          select 'Issue ID', from: 'mappings[field_attributes][0][type]'
          select 'Node', from: 'mappings[field_attributes][3][type]'
          select 'Evidence Field', from: 'mappings[field_attributes][4][type]'
          select 'Evidence Field', from: 'mappings[field_attributes][5][type]'

          perform_enqueued_jobs do
            click_button 'Import CSV'

            find('#console .log', wait: 30, match: :first)

            expect(page).to have_text('Worker process completed.')

            issue = Issue.last
            expect(issue.fields).to eq({ 'Description' => 'Test CSV', 'Title' => 'SQL Injection', 'VulnerabilityCategory' =>'High', 'plugin' => 'csv', 'plugin_id' => '1' })

            node = issue.affected.first
            expect(node.label).to eq('10.0.0.1')

            evidence = node.evidence.first
            expect(evidence.fields).to eq({ 'Label' => '10.0.0.1', 'Title' => 'SQL Injection', 'Location' => '10.0.0.1', 'Port' => '443' })
          end
        end
      end

      context 'when project have RTP' do
        before do
          rtp = create(:report_template_properties, evidence_fields: evidence_fields, issue_fields: issue_fields)
          @project.update(report_template_properties: rtp)

          page.refresh
        end

        context 'without fields' do
          let (:evidence_fields) { [] }
          let (:issue_fields) { [] }

          it 'creates records with fields from the headers' do
            select 'Issue ID', from: 'mappings[field_attributes][0][type]'
            select 'Node', from: 'mappings[field_attributes][3][type]'
            select 'Evidence Field', from: 'mappings[field_attributes][4][type]'
            select 'Evidence Field', from: 'mappings[field_attributes][5][type]'

            perform_enqueued_jobs do
              click_button 'Import CSV'

              find('#console .log', wait: 30, match: :first)

              expect(page).to have_text('Worker process completed.')

              issue = Issue.last
              expect(issue.fields).to eq({ 'Description' => 'Test CSV', 'Title' => 'SQL Injection', 'Vulnerability Category' =>'High', 'plugin' => 'csv', 'plugin_id' => '1' })

              node = issue.affected.first
              expect(node.label).to eq('10.0.0.1')

              evidence = node.evidence.first
              expect(evidence.fields).to eq({ 'Label' => '10.0.0.1', 'Location' => '10.0.0.1', 'Title' => 'SQL Injection', 'Port' => '443' })
            end
          end
        end

        context 'with fields' do
          let (:evidence_fields) {
            [
              { name: 'Location', type: :string, default: true },
              { name: 'Port', type: :string, default: true}
            ]
          }

          let (:issue_fields) {
            [
              { name: 'Title', type: :string, default: true },
              { name: 'Description', type: :string, default: true},
              { name: 'Severity', type: :string, default: true}
            ]
          }

          it 'shows the available fields for the selected type' do
            select 'Issue Field', from: 'mappings[field_attributes][1][type]'

            issue_fields.each do |field|
              expect(page).to have_selector('option', text: field[:name])
            end

            select 'Evidence Field', from: 'mappings[field_attributes][4][type]'

            evidence_fields.each do |field|
              expect(page).to have_selector('option', text: field[:name])
            end
          end

          it 'can select which columns to import' do
            select 'Issue ID', from: 'mappings[field_attributes][0][type]'

            select 'Issue Field', from: 'mappings[field_attributes][1][type]'
            select 'Title', from: 'mappings[field_attributes][1][field]'

            select 'Issue Field', from: 'mappings[field_attributes][2][type]'
            select 'Description', from: 'mappings[field_attributes][2][field]'

            select 'Node', from: 'mappings[field_attributes][3][type]'

            select 'Evidence Field', from: 'mappings[field_attributes][4][type]'
            select 'Location', from: 'mappings[field_attributes][4][field]'

            select 'Evidence Field', from: 'mappings[field_attributes][5][type]'
            select 'Port', from: 'mappings[field_attributes][5][field]'

            select 'Issue Field', from: 'mappings[field_attributes][6][type]'
            select 'Severity', from: 'mappings[field_attributes][6][field]'

            perform_enqueued_jobs do
              click_button 'Import CSV'

              find('#console .log', wait: 30, match: :first)

              expect(page).to have_text('Worker process completed.')

              issue = Issue.last
              expect(issue.fields).to eq({ 'Description' => 'Test CSV', 'Title' => 'SQL Injection', 'Severity' => 'High', 'plugin' => 'csv', 'plugin_id' => '1' })

              node = issue.affected.first
              expect(node.label).to eq('10.0.0.1')

              evidence = node.evidence.first
              expect(evidence.fields).to eq({ 'Label' => '10.0.0.1', 'Location' => '10.0.0.1', 'Title' => 'SQL Injection', 'Port' => '443' })
            end
          end
        end

        context 'when no evidence fields' do
          let (:evidence_fields) { [] }
          let (:issue_fields) { [] }

          it 'still creates evidence record' do
            within all('tbody tr')[0] do
              select 'Issue ID'
            end

            within all('tbody tr')[1] do
              select 'Issue Field'
            end

            within all('tbody tr')[3] do
              select 'Node'
            end

            within all('tbody tr')[5] do
              select 'Issue Field'
            end

            perform_enqueued_jobs do
              click_button 'Import CSV'

              find('#console .log', wait: 30, match: :first)

              expect(page).to have_text('Worker process completed.')

              issue = Issue.last
              expect(issue.fields).to include({ 'Title' => 'SQL Injection', 'plugin' => 'csv', 'plugin_id' => '1' })

              node = issue.affected.first
              expect(node.label).to eq('10.0.0.1')

              evidence = node.evidence.first
              expect(evidence.content).to eq('')
            end
          end
        end
      end
    end
  end

  context 'saving a mapping', js: true do
    let(:file_path) { File.expand_path('../fixtures/files/simple.csv', __dir__) }
    let(:rtp) do
      create(:report_template_properties,
        issue_fields: [{ name: 'Title', type: :string, default: true }],
        evidence_fields: []
      )
    end

    before do
      @project.update(report_template_properties: rtp)

      find('#state + .combobox').click
      find('#state ~ .combobox-menu .combobox-option', text: 'Published').click

      find('#uploader + .combobox').click
      find('#uploader ~ .combobox-menu .combobox-option', text: 'Dradis::Plugins::CSV').click

      attach_file 'file', file_path, visible: false, disabled: false
      expect(page).to have_text('CSV Upload Mapping', wait: 30)
    end

    it 'creates a Mapping record when checkbox is checked and name is provided' do
      select 'Issue ID', from: 'mappings[field_attributes][0][type]'
      select 'Node', from: 'mappings[field_attributes][3][type]'
      check 'save_mapping'
      fill_in 'mapping_source_name', with: 'Prowler'

      expect do
        perform_enqueued_jobs { click_button 'Import CSV' }
      end.to change(Mapping, :count).by(1)

      mapping = Mapping.last
      expect(mapping.source).to eq('Prowler')
      expect(mapping.component).to eq('csv')
      expect(mapping.mapping_fields.pluck(:destination_field)).to include('Issue ID', 'Node Label')
    end

    it 'does not create a Mapping record when checkbox is unchecked' do
      select 'Issue ID', from: 'mappings[field_attributes][0][type]'
      select 'Node', from: 'mappings[field_attributes][3][type]'

      expect do
        perform_enqueued_jobs { click_button 'Import CSV' }
      end.not_to change(Mapping, :count)
    end
  end

  context 'loading a saved mapping', js: true do
    let(:file_path) { File.expand_path('../fixtures/files/simple.csv', __dir__) }
    let(:rtp) do
      create(:report_template_properties,
        issue_fields: [{ name: 'Title', type: :string, default: true }],
        evidence_fields: []
      )
    end
    let!(:saved_mapping) do
      mapping = Mapping.create!(
        component: 'csv',
        source: 'Test Mapping',
        destination: "rtp_#{rtp.id}"
      )
      MappingField.create!(mapping: mapping, source_field: 'Title', destination_field: 'Issue ID', content: 'Title')
      MappingField.create!(mapping: mapping, source_field: 'Description', destination_field: 'Issue: Title', content: 'Description')
      mapping
    end

    before do
      @project.update(report_template_properties: rtp)

      find('#state + .combobox').click
      find('#state ~ .combobox-menu .combobox-option', text: 'Published').click

      find('#uploader + .combobox').click
      find('#uploader ~ .combobox-menu .combobox-option', text: 'Dradis::Plugins::CSV').click

      attach_file 'file', file_path, visible: false, disabled: false
      expect(page).to have_text('CSV Upload Mapping', wait: 30)
    end

    it 'auto-fills rows matching the saved mapping' do
      find('#saved_mapping + .combobox').click
      find('#saved_mapping ~ .combobox-menu .combobox-option', text: 'Test Mapping').click

      expect(page).to have_select('mappings[field_attributes][0][type]', selected: 'Issue ID')
      expect(page).to have_select('mappings[field_attributes][1][type]', selected: 'Issue Field')
    end

    it 'resets rows not in the mapping to Do Not Import' do
      find('#saved_mapping + .combobox').click
      find('#saved_mapping ~ .combobox-menu .combobox-option', text: 'Test Mapping').click

      expect(page).to have_select('mappings[field_attributes][2][type]', selected: 'Do Not Import')
    end
  end

  describe 'CSV file samples' do
    before do
      find('#uploader + .combobox').click
      find('#uploader ~ .combobox-menu .combobox-option', text: 'Dradis::Plugins::CSV').click

      attach_file 'file', file_path, visible: false, disabled: false
    end

    context 'uploading a malformed CSV file' do
      let(:file_path) { File.expand_path('../fixtures/files/simple_malformed.csv', __dir__) }

      it 'redirects to upload manager with error' do
        find('.alert.alert-danger', wait: 30)

        expect(page).to have_text('The uploaded file is not a valid CSV file')
        expect(current_path).to eq(main_app.project_upload_manager_path(@project))
      end
    end

    context 'uploading any file other than CSV' do
      let(:file_path) { Rails.root.join('spec/fixtures/files/rails.png') }

      it 'redirects to upload manager with error' do
        find('.alert.alert-danger', wait: 30)

        expect(page).to have_text('The uploaded file is not a CSV file.')
        expect(current_path).to eq(main_app.project_upload_manager_path(@project))
      end
    end
  end
end
