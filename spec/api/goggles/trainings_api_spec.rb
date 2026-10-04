# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::TrainingsAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  let(:admin_user) { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }

  let(:fixture_row) { FactoryBot.create(:training_with_picture) }
  let(:swimmer) { FactoryBot.create(:swimmer) }

  let(:image_path) { GogglesDb::Engine.root.join('spec', 'fixtures', 'files', 'test_creative_training.jpg') }
  let(:image_file) { Rack::Test::UploadedFile.new(image_path, 'image/jpeg') }
  let(:png_file) { Rack::Test::UploadedFile.new(GogglesDb::Engine.root.join('spec', 'fixtures', 'files', 'test_creative_training.png'), 'image/png') }

  let(:valid_params) do
    {
      image: image_file,
      training_by: 'Test Trainer',
      created_by: 'Test Creator',
      training_date: '2026-10-01 18:30',
      swimmer_id: swimmer.id,
      description: "5x100 FR pull\n3x200 IM"
    }
  end

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::Training).and be_valid
    expect(fixture_row.picture.attached?).to be true
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
    expect(admin_user).to be_a(GogglesDb::User).and be_valid
    expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(admin_headers).to be_an(Hash).and have_key('Authorization')
    expect(File.exist?(image_path)).to be true
  end

  describe 'GET /api/v3/training/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_training_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful request that has positive usage stats')

      it 'returns the row attributes and computed image fields' do
        result = JSON.parse(response.body)
        expect(result['id']).to eq(fixture_row.id)
        expect(result['training_by']).to eq(fixture_row.training_by)
        expect(result['created_by']).to eq(fixture_row.created_by)
        expect(result['picture_filename']).to eq('test_creative_training.jpg')
        expect(result['image_path']).to be_present.and start_with('/rails/active_storage/')
        expect(result['image_thumb_path']).to be_present.and start_with('/rails/active_storage/')
        expect(result['image_missing']).to be false
      end
    end

    context 'when the attached image file is missing from storage,' do
      before do
        FileUtils.rm_f(fixture_row.picture.blob.service.send(:path_for, fixture_row.picture.blob.key))
        get(api_v3_training_path(id: fixture_row.id), headers: fixture_headers)
      end

      it 'flags the row as image_missing' do
        expect(response).to be_successful
        result = JSON.parse(response.body)
        expect(result['picture_filename']).to eq('test_creative_training.jpg')
        expect(result['image_missing']).to be true
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_training_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_training_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before do
        expect(GogglesDb::Training.exists?(0)).to be false
        get api_v3_training_path(id: 0), headers: fixture_headers
      end

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/training' do
    shared_examples_for('a successful multipart POST returning the new row ID') do
      it 'returns an OK message and the new row ID as a JSON object' do
        result = JSON.parse(response.body)
        expect(result).to have_key('msg').and have_key('new')
        expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
        resulting_id = result['new']['id'].to_i
        expect(resulting_id).to be_positive
        new_row = GogglesDb::Training.find(resulting_id)
        expect(new_row).to be_valid
        expect(new_row.picture.attached?).to be true
        expect(new_row.picture_filename).to eq(File.basename(image_path))
      end
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_training_path, params: valid_params, headers: admin_headers) }

        it_behaves_like('a successful multipart POST returning the new row ID')

        it 'stores the specified attributes and auto-builds the title' do
          new_row = GogglesDb::Training.last
          expect(new_row.training_by).to eq('Test Trainer')
          expect(new_row.created_by).to eq('Test Creator')
          expect(new_row.training_date.to_date).to eq(Date.new(2026, 10, 1))
          expect(new_row.swimmer_id).to eq(swimmer.id)
          expect(new_row.description).to include('5x100 FR')
          expect(new_row.title).to start_with('2026-10-01 Test Creator')
        end
      end

      context 'with a regular (non-admin) account,' do
        before { post(api_v3_training_path, params: valid_params, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when the image file param is missing,' do
      before { post(api_v3_training_path, params: valid_params.except(:image), headers: admin_headers) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end
    end

    context 'when a required string param is missing,' do
      before { post(api_v3_training_path, params: valid_params.except(:training_by), headers: admin_headers) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end
    end

    context 'when the given swimmer_id does not exist,' do
      before { post(api_v3_training_path, params: valid_params.merge(swimmer_id: 0), headers: admin_headers) }

      it 'is NOT successful and reports the invalid parameter' do
        expect(response).not_to be_successful
        expect(response.headers['X-Error-Detail']).to include('Swimmer')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_training_path, params: valid_params, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/training/:id' do
    let(:expected_changes) { { created_by: 'Updated Creator', description: 'Updated text' } }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { put(api_v3_training_path(id: fixture_row.id), params: expected_changes, headers: admin_headers) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'updates the row and returns the enriched payload' do
          result = JSON.parse(response.body)
          expect(result['id']).to eq(fixture_row.id)
          expect(result['created_by']).to eq('Updated Creator')
          expect(result['description']).to eq('Updated text')
          expect(result['picture_filename']).to eq('test_creative_training.jpg')
          fixture_row.reload
          expect(fixture_row.created_by).to eq('Updated Creator')
        end
      end

      context 'with a regular (non-admin) account,' do
        before { put(api_v3_training_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when re-uploading a missing image file,' do
      before do
        blob = fixture_row.picture.blob
        FileUtils.rm_f(blob.service.send(:path_for, blob.key))
        put(
          api_v3_training_path(id: fixture_row.id),
          params: { image: png_file },
          headers: admin_headers
        )
      end

      it 're-attaches the picture and clears the missing flag' do
        expect(response).to be_successful
        result = JSON.parse(response.body)
        expect(result['picture_filename']).to eq('test_creative_training.png')
        expect(result['image_missing']).to be false
      end
    end

    context 'when the given swimmer_id does not exist,' do
      before { put(api_v3_training_path(id: fixture_row.id), params: { swimmer_id: 0 }, headers: admin_headers) }

      it 'is NOT successful and reports the invalid parameter' do
        expect(response).not_to be_successful
        expect(response.headers['X-Error-Detail']).to include('Swimmer')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_training_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before do
        expect(GogglesDb::Training.exists?(0)).to be false
        put api_v3_training_path(id: 0), params: expected_changes, headers: admin_headers
      end

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/training/:id' do
    context 'when using valid parameters,' do
      let(:deletable_row) { fixture_row }

      context 'with an account having ADMIN grants,' do
        before { delete(api_v3_training_path(id: fixture_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON DELETE response')

        it 'removes the row and its attachment' do
          expect(GogglesDb::Training.exists?(fixture_row.id)).to be false
          expect(ActiveStorage::Attachment.where(record_type: 'GogglesDb::Training', record_id: fixture_row.id)).not_to exist
        end
      end

      context 'with a regular (non-admin) account,' do
        before { delete(api_v3_training_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_training_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before do
        expect(GogglesDb::Training.exists?(0)).to be false
        delete api_v3_training_path(id: 0), headers: admin_headers
      end

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/trainings' do
    let(:default_per_page) { 25 }

    context 'when using valid parameters,' do
      before do
        fixture_row # enforce creation
        get(api_v3_trainings_path, headers: fixture_headers)
      end

      it_behaves_like('successful single response without pagination links in headers')

      it 'returns only rows with an attached picture' do
        results = JSON.parse(response.body)
        expect(results).not_to be_empty
        expect(results.pluck('id')).to include(fixture_row.id)
        # Legacy seeded rows without any picture are excluded:
        expect(results.pluck('picture_filename')).to all(be_present)
        expect(results.pluck('image_path')).to all(be_present)
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_trainings_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end
  end
end
