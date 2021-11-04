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

  before do
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
    expect(fixture_pool_type).to be_a(GogglesDb::PoolType).and be_valid
    expect(fixture_event_type).to be_a(GogglesDb::EventType).and be_valid
    expect(fixture_mir).to be_a(GogglesDb::MeetingIndividualResult).and be_valid
    expect(fixture_meeting).to be_a(GogglesDb::Meeting).and be_valid
    expect(fixture_swimmer).to be_a(GogglesDb::Swimmer).and be_valid
  end
  #-- -------------------------------------------------------------------------
  #++

  # REQUIRES/ASSUMES:
  # - 'result_hash': the parsed JSON response from the API call.
  shared_examples_for('result_hash including a Timing object with a dedicated label field') do |label_key, timing_field_key|
    it "returns a '#{label_key}' field text, with format <nn'nn\"nn> when non-empty" do
      expect(result_hash).to have_key(label_key)
      expect(result_hash[label_key]).to match(/\d{1,2}'\d{1,2}"\d{1,2}/) if result_hash[label_key].present?
    end

    it "returns a '#{timing_field_key}' hash, when the StandardTime is found (otherwise nil)" do
      expect(result_hash).to have_key(timing_field_key)
      if result_hash[timing_field_key].present?
        expect(result_hash[timing_field_key]).to be_a(Hash)
        expect(result_hash[timing_field_key]).to have_key('minutes')
        expect(result_hash[timing_field_key]).to have_key('seconds')
        expect(result_hash[timing_field_key]).to have_key('hundredths')
      end
    end

    it "has the '#{label_key}' field equal to the default string representation of its '#{timing_field_key}' field (when non-empty)" do
      timing = Timing.new(
        hundredths: result_hash[timing_field_key]&.fetch('hundredths', nil),
        seconds: result_hash[timing_field_key]&.fetch('seconds', nil),
        minutes: result_hash[timing_field_key]&.fetch('minutes', nil),
        hours: result_hash[timing_field_key]&.fetch('hours', nil),
        days: result_hash[timing_field_key]&.fetch('days', nil)
      )
      expect(result_hash[label_key]).to eq(timing.to_s) if result_hash[timing_field_key].present?
    end
  end

  describe 'GET /api/v3/tools/find_entry_time' do
    let(:api_request_params) do
      {
        swimmer_id: fixture_swimmer.id, meeting_id: fixture_meeting.id,
        event_type_id: fixture_event_type.id, pool_type_id: fixture_pool_type.id
      }
    end

    context 'when using a valid authentication' do
      context 'with valid parameters (corresponding to existing entities)' do
        before { get(api_v3_tools_find_entry_time_path, params: api_request_params, headers: fixture_headers) }

        let(:result_hash) { JSON.parse(response.body) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'returns a valid JSON hash' do
          expect(result_hash).to be_a(Hash)
        end

        it_behaves_like(
          'result_hash including a Timing object with a dedicated label field',
          'label', 'timing'
        )
      end

      context 'when using valid parameters but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_tools_find_entry_time_path, params: api_request_params, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with parameters that do not match existing entities' do
        let(:failing_request_params) do
          {
            swimmer_id: -fixture_swimmer.id,
            event_type_id: fixture_event_type.id,
            pool_type_id: fixture_pool_type.id
          }
        end

        before { get(api_v3_tools_find_entry_time_path, params: failing_request_params, headers: fixture_headers) }

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
      before { get(api_v3_tools_find_entry_time_path, params: api_request_params, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/tools/compute_score' do
    let(:api_score_request_params) do
      {
        event_type_id: fixture_event_type.id, pool_type_id: fixture_pool_type.id,
        minutes: fixture_mir.minutes, seconds: fixture_mir.seconds, hundredths: fixture_mir.hundredths,
        badge_id: fixture_mir.badge_id
      }
    end
    let(:api_timing_request_params) do
      {
        event_type_id: fixture_event_type.id, pool_type_id: fixture_pool_type.id,
        score: fixture_mir.standard_points.to_i, badge_id: fixture_mir.badge_id
      }
    end

    context 'when using a valid authentication' do
      context 'with valid parameters for computing the score,' do
        before { get(api_v3_tools_compute_score_path, params: api_score_request_params, headers: fixture_headers) }

        let(:result_hash) { JSON.parse(response.body) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'returns a valid JSON hash' do
          expect(result_hash).to be_a(Hash)
        end

        it "returns a non-empty 'score' field (the computed score)" do
          expect(result_hash).to have_key('score')
          expect(result_hash['score']).to be_present
          # In case the StandardTiming wasn't found we only know for sure it will return the default standard points:
          expect(result_hash['score']).to eq(1000) if result_hash['standard_timing'].blank?
          # NOTE
          # We cannot assert the exact value because we are using fixture results that may
          # refer to standard timings that may have been updated after the result score was computed.
        end

        it "returns a non-empty 'standard_points' field" do
          expect(result_hash).to have_key('standard_points')
          expect(result_hash['standard_points']).to be_present
          expect(result_hash['standard_points']).to eq(1000)
        end

        it "returns the standard timing 'display_label' field (when the standard time is found)" do
          expect(result_hash).to have_key('display_label')
          expect(result_hash['display_label']).to be_present if result_hash['standard_timing'].present?
        end

        it "returns the standard timing 'short_label' field (when the standard time is found)" do
          expect(result_hash).to have_key('short_label')
          expect(result_hash['short_label']).to be_present if result_hash['standard_timing'].present?
        end

        it_behaves_like(
          'result_hash including a Timing object with a dedicated label field',
          'timing_label', 'timing'
        )

        it_behaves_like(
          'result_hash including a Timing object with a dedicated label field',
          'standard_timing_label', 'standard_timing'
        )
      end

      context 'with valid parameters for computing the target time,' do
        before { get(api_v3_tools_compute_score_path, params: api_timing_request_params, headers: fixture_headers) }

        let(:result_hash) { JSON.parse(response.body) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'returns a valid JSON hash' do
          expect(result_hash).to be_a(Hash)
        end

        it "returns a non-empty 'score' field, equal to the specified score parameter" do
          expect(result_hash).to have_key('score')
          expect(result_hash['score']).to be_present
          expect(result_hash['score']).to eq(fixture_mir.standard_points.to_i)
        end

        it "has the 'timing' Hash field as the computed target timing" do
          expect(result_hash).to have_key('timing')
          expect(result_hash['timing']).to be_a(Hash)
          timing = Timing.new(
            hundredths: result_hash['timing']['hundredths'],
            seconds: result_hash['timing']['seconds'],
            minutes: result_hash['timing']['minutes'],
            hours: result_hash['timing']['hours'],
            days: result_hash['timing']['days']
          )
          # In case the StandardTiming wasn't found we only know for sure it will return zero:
          expect(timing).to eq(Timing.new) if result_hash['standard_timing'].blank?
          # NOTE
          # We cannot assert the exact value because we are using fixture results that may
          # refer to standard timings that may have been updated after the result score was computed.
        end

        it "returns a non-empty 'standard_points' field" do
          expect(result_hash).to have_key('standard_points')
          expect(result_hash['standard_points']).to be_present
          expect(result_hash['standard_points']).to eq(1000)
        end

        it "returns the standard timing 'display_label' field (when the standard time is found)" do
          expect(result_hash).to have_key('display_label')
          expect(result_hash['display_label']).to be_present if result_hash['standard_timing'].present?
        end

        it "returns the standard timing 'short_label' field (when the standard time is found)" do
          expect(result_hash).to have_key('short_label')
          expect(result_hash['short_label']).to be_present if result_hash['standard_timing'].present?
        end

        it_behaves_like(
          'result_hash including a Timing object with a dedicated label field',
          'timing_label', 'timing'
        )

        it_behaves_like(
          'result_hash including a Timing object with a dedicated label field',
          'standard_timing_label', 'standard_timing'
        )
      end

      context 'when using valid parameters for computing the score but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_tools_compute_score_path, params: api_score_request_params, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when using valid parameters for computing the target time but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_tools_compute_score_path, params: api_timing_request_params, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with invalid or missing parameters' do
        let(:failing_request_params) do
          { event_type_id: fixture_event_type.id, pool_type_id: fixture_pool_type.id }
        end

        before { get(api_v3_tools_compute_score_path, params: failing_request_params, headers: fixture_headers) }

        it 'is successful anyway (because it is a kind of warning)' do
          expect(response).to be_successful
        end

        it 'responds with an errors sub-hash with the actual error message in it' do
          result = JSON.parse(response.body)
          expect(result).to have_key('errors')
          expect(result['errors']).to have_key('msg')
          expect(result['errors']['msg']).to eq('Invalid or missing constructor parameters')
        end
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_tools_compute_score_path, params: api_score_request_params, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
