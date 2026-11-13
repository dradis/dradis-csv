require 'rails_helper'

RSpec.describe Dradis::Plugins::CSV::MappingImportJob do
  let(:file) { File.expand_path('../../../.../../../fixtures/files/simple.csv', __dir__) }

  let(:perform_job) do
    described_class.new.perform(
      default_user_id: create(:user).id,
      file: file,
      headers: CSV.open(file, &:readline),
      mappings: {},
      project_id: create(:project).id,
      state: 'draft',
      uid: 1
    )
  end

  describe '#perform' do
    it 'calls Importer#import_rows' do
      dbl = double('Importer')
      allow(Dradis::Plugins::CSV::Importer).to receive(:new).and_return(dbl)
      expect(dbl).to receive(:import_rows).and_return(true)

      perform_job
    end

    it 'writes the completed line' do
      perform_job
      expect(Log.last.text).to eq Log::COMPLETED
    end

    it 'writes the error and the failed line, then re-raises, when the import raises' do
      allow_any_instance_of(Dradis::Plugins::CSV::Importer).to receive(:import_rows).and_raise('Boom')

      expect { perform_job }.to raise_error('Boom')

      expect(Log.where(uid: 1).pluck(:text).last(2)).to eq [
        'There was an error with the upload: Boom',
        Log::FAILED
      ]
    end
  end
end
