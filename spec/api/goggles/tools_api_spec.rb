# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::ToolsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Build up test domain by selecting a valid MIR and from that obtain all parameters:
  let(:fixture_pool_type)  { GogglesDb::PoolType.all_eventable.sample }
  let(:fixture_event_type) do
    GogglesDb::EventsByPoolType.eventable.individuals
                               .for_pool_type(fixture_pool_type)
                               .event_length_between(50, 1500)
                               .sample
                               .event_type
  end
  let(:fixture_mir) do
    GogglesDb::MeetingIndividualResult.includes(:pool_type, :event_type)
                                      .joins(:pool_type, :event_type)
                                      .qualifications
                                      .where(
                                        'pool_types.id': fixture_pool_type.id,
                                        'event_types.id': fixture_event_type.id
                                      ).limit(500).sample
  end
  let(:fixture_swimmer) { fixture_mir.swimmer }
  let(:fixture_meeting) { fixture_mir.meeting }
  let(:api_request_params) do
    {
      swimmer_id: fixture_swimmer.id, meeting_id: fixture_meeting.id,
      event_type_id: fixture_event_type.id, pool_type_id: fixture_pool_type.id
    }
  end

  before(:each) do
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
    expect(fixture_pool_type).to be_a(GogglesDb::PoolType).and be_valid
    expect(fixture_event_type).to be_a(GogglesDb::EventType).and be_valid
    expect(fixture_mir).to be_a(GogglesDb::MeetingIndividualResult).and be_valid
    expect(fixture_meeting).to be_a(GogglesDb::Meeting).and be_valid
    expect(fixture_swimmer).to be_a(GogglesDb::Swimmer).and be_valid
  end

  describe 'GET /api/v3/Tools/:entity_name' do
    context 'when using a valid authentication' do
      context 'with valid parameters (corresponding to existing entities)' do
        before(:each) { get(api_v3_tools_find_entry_time_path, params: api_request_params, headers: fixture_headers) }
        let(:result_hash) { JSON.parse(response.body) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'returns a valid JSON hash' do
          expect(result_hash).to be_a(Hash)
        end
        it "returns a non-empty 'label' field text, with format <nn'nn\"nn>" do
          expect(result_hash).to have_key('label')
          expect(result_hash['label']).to be_present
          expect(result_hash['label']).to match(/\d{1,2}'\d{1,2}"\d{1,2}/)
        end
        it "returns a non-empty 'timing' hash" do
          expect(result_hash).to have_key('timing')
          expect(result_hash['timing']).to be_a(Hash)
          expect(result_hash['timing']).to have_key('minutes')
          expect(result_hash['timing']).to have_key('seconds')
          expect(result_hash['timing']).to have_key('hundredths') # (sic: "hundredths")
        end
        it "has the 'label' field equal to the default string representation of its 'timing' field" do
          timing = Timing.new(
            hundredths: result_hash['timing']['hundredths'],
            seconds: result_hash['timing']['seconds'],
            minutes: result_hash['timing']['minutes'],
            hours: result_hash['timing']['hours'],
            days: result_hash['timing']['days']
          )
          expect(result_hash['label']).to eq(timing.to_s)
        end
      end

      context 'with parameters that do not match existing entities' do
        let(:failing_request_params) do
          {
            swimmer_id: -fixture_swimmer.id,
            event_type_id: fixture_event_type.id,
            pool_type_id: fixture_pool_type.id
          }
        end
        before(:each) { get(api_v3_tools_find_entry_time_path, params: failing_request_params, headers: fixture_headers) }

        it 'is NOT successful' do
          expect(response).not_to be_successful
        end
        it 'responds with a generic parameter error message and the details about the class and the ID in the header' do
          result = JSON.parse(response.body)
          expect(result).to have_key('error')
          expect(result['error']).to eq(I18n.t('api.message.invalid_parameter'))
          expect(response.headers).to have_key('X-Error-Detail')
          expect(response.headers['X-Error-Detail']).to include('Swimmer').and include((-fixture_swimmer.id).to_s)
        end
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_tools_find_entry_time_path, params: api_request_params, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end
  end
end
