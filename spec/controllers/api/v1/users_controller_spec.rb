require 'spec_helper'

describe Api::V1::UsersController do
  describe 'current' do
    it 'returns user_present = false if there is no user present' do
      get :current, format: :json
      expect(response.code).to eq('200')
      expect(response.headers['Access-Control-Allow-Origin']).not_to be_present
      expect(response.headers['Access-Control-Request-Method']).not_to be_present
    end

    it 'returns user_present if a user is present' do
      # We need to test that cors isn't present
      u = FactoryGirl.create(:user)
      set_current_user(u)
      get :current, format: :json
      expect(response.code).to eq('200')
      # pp response.body
      expect(JSON.parse(response.body)).to include('user_present' => true)
      expect(response.headers['Access-Control-Allow-Origin']).not_to be_present
      expect(response.headers['Access-Control-Request-Method']).not_to be_present
    end
  end

  describe 'send_request' do
    it 'actuallies send the mail' do
      Sidekiq::Testing.inline! do
        # We don't test that this is being added to Sidekiq
        # Because we're testing that sidekiq does what it
        # Needs to do here. Slow tests, but we know it actually works :(
        o = FactoryGirl.create(:ownership)
        user = o.creator
        bike = o.bike
        delete_request = {
          request_type: 'bike_delete_request',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Some reason'
        }
        set_current_user(user)
        ActionMailer::Base.deliveries = []
        post :send_request, delete_request
        expect(response.code).to eq('200')
        expect(ActionMailer::Base.deliveries).not_to be_empty
      end
    end
    context 'manufacturer_update_manufacturer present' do
      it 'updates the manufacturer' do
        o = FactoryGirl.create(:ownership)
        manufacturer = FactoryGirl.create(:manufacturer)
        user = o.creator
        bike = o.bike
        update_manufacturer_request = {
          request_type: 'manufacturer_update_manufacturer',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Need to update manufacturer',
          manufacturer_update_manufacturer: manufacturer.slug
        }
        set_current_user(user)
        post :send_request, update_manufacturer_request
        expect(response.code).to eq('200')
        bike.reload
        expect(bike.manufacturer).to eq manufacturer
      end
    end

    context 'manufacturer_update_manufacturer present' do
      it 'does not make nil manufacturer' do
        o = FactoryGirl.create(:ownership)
        user = o.creator
        bike = o.bike
        update_manufacturer_request = {
          request_type: 'manufacturer_update_manufacturer',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Need to update manufacturer',
          manufacturer_update_manufacturer: 'doadsfizxcv'
        }
        set_current_user(user)
        post :send_request, update_manufacturer_request
        expect(response.code).to eq('200')
        bike.reload
        expect(bike.manufacturer).to be_present
      end
    end

    context 'serial request mail' do
      it "doesn't create a new serial request mail" do
        o = FactoryGirl.create(:ownership)
        user = o.creator
        bike = o.bike
        serial_request = {
          request_type: 'serial_update_request',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Some reason',
          serial_update_serial: 'some new serial'
        }
        set_current_user(user)
        expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
        expect do
          post :send_request, serial_request
        end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
        expect(response.code).to eq('200')
        expect(bike.reload.serial_number).to eq('some new serial')
      end
    end

    it 'it untsvs a bike' do
      t = Time.now - 1.minute
      stolenRecord = FactoryGirl.create(:stolenRecord, tsved_at: t)
      o = FactoryGirl.create(:ownership, bike: stolenRecord.bike)
      user = o.creator
      bike = o.bike
      bike.update_attribute :current_stolenRecord_id, bike.find_current_stolenRecord.id
      serial_request = {
        request_type: 'serial_update_request',
        user_id: user.id,
        request_bike_id: bike.id,
        request_reason: 'Some reason',
        serial_update_serial: 'some new serial'
      }
      set_current_user(user)
      expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
      post :send_request, serial_request
      expect(response.code).to eq('200')
      bike.reload
      expect(bike.serial_number).to eq('some new serial')
      stolenRecord.reload
      expect(stolenRecord.tsved_at).to be_nil
    end

    it 'creates a new recovery request mail' do
      Sidekiq::Testing.inline! do
        # We don't test that this is being added to Sidekiq
        # Because we're testing that sidekiq does what it
        # Needs to do here.
        o = FactoryGirl.create(:ownership)
        user = o.creator
        bike = o.bike
        stolenRecord = FactoryGirl.create(:stolenRecord, bike: bike)
        bike.update_attribute :stolen, true
        recovery_request = {
          request_type: 'bike_recovery',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Some reason',
          index_helped_recovery: 'true',
          can_share_recovery: 'true',
          mark_recovered_stolenRecord_id: stolenRecord.id
        }
        set_current_user(user)
        bike.reload.update_attributes(stolen: false, current_stolenRecord_id: nil)
        bike.reload
        post :send_request, recovery_request.as_json
        expect(response.code).to eq('200')
        expect(flash[:error]).not_to be_present
        expect(bike.reload.stolen).to be_falsey
        # ALSO MAKE SURE IT RECOVERY NOTIFIES
        expect(stolenRecord.reload.current).to be_falsey
        expect(stolenRecord.bike).to eq(bike)
        expect(stolenRecord.date_recovered).to be_present
        expect(stolenRecord.recovery_posted).to be_falsey
        expect(stolenRecord.index_helped_recovery).to be_truthy
        expect(stolenRecord.can_share_recovery).to be_truthy
      end
    end

    it "does not create a new serial request mailer if a user isn't present" do
      bike = FactoryGirl.create(:bike)
      message = { request_bike_id: bike.id, serial_update_serial: 'some update', request_reason: 'Some reason' }
      # pp message
      post :send_request, message, format: :json
      expect(response.code).to eq('403')
    end

    it 'does not create a new serial request mailer if wrong user user is present' do
      o = FactoryGirl.create(:ownership)
      bike = o.bike
      user = FactoryGirl.create(:user)
      set_current_user(user)
      params = { request_bike_id: bike.id, serial_update_serial: 'some update', request_reason: 'Some reason' }
      post :send_request, params
      # pp response
      expect(response.code).to eq('403')
    end
  end
end
