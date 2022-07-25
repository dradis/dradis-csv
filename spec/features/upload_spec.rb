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
      select 'Dradis::Plugins::CSV', from: 'uploader'

      within('.custom-file') do
        page.find('#file', visible: false).attach_file(file_path)
      end

      find('body.upload.new', wait: 30)
    end

    it 'redirects to the mapping page' do
      expect(current_path).to eq(csv.new_project_upload_path(@project))
    end

    it 'lists the fields in the table', focus: true do
      headers = CSV.open(file_path, &:readline)

      within('tbody') do
        headers.each do |header|
          expect(page).to have_selector('td', text: header)
        end
      end
    end
  end
end
