require "rails_helper"

RSpec.describe UserPhonesController, type: :request do
  let(:base_url) { "/user_phones" }
  let(:phone) { "7733234433" } # ensure it's a valid phone number to not get twilio error

  it "redirects if user not present" do
    user_phone = FactoryBot.create(:user_phone)
    user_phone.update_column :updated_at, Time.current - 5.minutes
    expect(user_phone.resend_confirmation?).to be_truthy
    expect {
      Sidekiq::Testing.inline! {
        patch "#{base_url}/#{user_phone.to_param}", params: {resend_confirmation: true}
      }
    }.to_not change(Notification, :count)
    expect(response).to redirect_to(/session\/new/)
  end

  context "with user present" do
    include_context :request_spec_logged_in_as_user
    let!(:user_phone) { FactoryBot.create(:user_phone, user: current_user, confirmation_code: "6666666", phone: phone) }
    it "resends if reasonable and verifies" do
      expect(current_user).to be_present
      user_phone.update_column :updated_at, Time.current - 5.minutes
      user_phone.reload
      expect(user_phone.confirmed?).to be_falsey
      expect(user_phone.confirmation_code).to eq "6666666"
      expect(user_phone.resend_confirmation?).to be_truthy
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.inline! {
        VCR.use_cassette("user_phones_controller-resend", match_requests_on: [:path]) do
          expect {
            patch "#{base_url}/#{user_phone.to_param}", params: {resend_confirmation: true}
          }.to change(Notification, :count).by 1
        end

        current_user.reload
        expect(current_user.user_phones.count).to eq 1
        expect(current_user.phone_waiting_confirmation?).to be_truthy
        expect(current_user.general_alerts).to eq(["phone_waiting_confirmation"])

        user_phone.reload
        expect(user_phone.confirmed?).to be_falsey
        expect(user_phone.notifications.count).to eq 1
        expect(user_phone.confirmation_code).to_not eq "6666666"
        expect(user_phone.resend_confirmation?).to be_falsey


        # And then, so we don't have to set everything up again, test confirmation in here
        VCR.use_cassette("user_phones_controller-resend", match_requests_on: [:path]) do
          patch "#{base_url}/#{user_phone.to_param}", params: {confirmation_code: user_phone.confirmation_code}
        end

        current_user.reload
        expect(current_user.phone_waiting_confirmation?).to be_falsey
        expect(current_user.user_phones.count).to eq 1
        expect(current_user.general_alerts).to eq([])

        user_phone.reload
        expect(user_phone.confirmed?).to be_truthy
        expect(user_phone.confirmed_at).to be_within(5).of Time.current
      }
    end

    describe "confirm" do
      context "incorrect confirmation" do
        it "does not confirm" do
          user_phone.reload
          expect(user_phone.confirmed?).to be_falsey
          patch "#{base_url}/#{user_phone.to_param}", params: {confirmation_code: "11111111"}
          expect(flash[:error]).to be_present

          current_user.reload
          expect(current_user.user_phones.count).to eq 1
          expect(current_user.phone_waiting_confirmation?).to be_truthy

          user_phone.reload
          expect(user_phone.confirmed?).to be_falsey
          expect(user_phone.notifications.count).to eq 0
          expect(user_phone.confirmation_code).to eq "6666666"
          expect(user_phone.resend_confirmation?).to be_falsey
        end
      end
      context "outside of confirmation time" do
        it "does not confirm" do
          user_phone.update_column :updated_at, Time.current - 1.hour
          user_phone.reload
          expect(user_phone.confirmed?).to be_falsey
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! {
            expect {
              VCR.use_cassette("user_phones_controller-resend", match_requests_on: [:path]) do
                patch "#{base_url}/#{user_phone.to_param}", params: {confirmation_code: "6666666"}
              end
            }.to change(Notification, :count).by 1
          }
          expect(flash[:error]).to match(/expire/i)

          current_user.reload
          expect(current_user.user_phones.count).to eq 1
          expect(current_user.phone_waiting_confirmation?).to be_truthy

          user_phone.reload
          expect(user_phone.confirmed?).to be_falsey
          expect(user_phone.notifications.count).to eq 1
          expect(user_phone.confirmation_code).to_not eq "6666666"
          expect(user_phone.resend_confirmation?).to be_falsey
        end
      end
    end

    describe "resend_confirmation" do
      context "not reasonable to resend" do
        it "does not resend" do
          user_phone.reload
          expect(user_phone.confirmed?).to be_falsey
          expect(user_phone.resend_confirmation?).to be_falsey
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! {
            expect {
              patch "#{base_url}/#{user_phone.to_param}", params: {resend_confirmation: true}
            }.to_not change(Notification, :count)
          }

          current_user.reload
          expect(current_user.user_phones.count).to eq 1
          expect(current_user.phone_waiting_confirmation?).to be_truthy

          user_phone.reload
          expect(user_phone.confirmed?).to be_falsey
          expect(user_phone.notifications.count).to eq 0
          expect(user_phone.confirmation_code).to eq "6666666"
          expect(user_phone.resend_confirmation?).to be_falsey
        end
      end
      context "legacy" do
        let!(:user_phone) { FactoryBot.create(:user_phone, user: current_user, confirmation_code: "legacy_migration", phone: phone) }
        it "resends" do
          user_phone.reload
          expect(user_phone.confirmed?).to be_falsey
          expect(user_phone.legacy?).to be_truthy
          expect(user_phone.resend_confirmation?).to be_truthy
          current_user.reload
          expect(current_user.phone_waiting_confirmation?).to be_falsey
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! {
            VCR.use_cassette("user_phones_controller-resend", match_requests_on: [:path]) do
              expect {
                patch "#{base_url}/#{user_phone.to_param}", params: {resend_confirmation: true}
              }.to change(Notification, :count).by 1
            end
          }
          expect(flash[:success]).to be_present
          current_user.reload
          expect(current_user.user_phones.count).to eq 1
          expect(current_user.phone_waiting_confirmation?).to be_truthy

          user_phone.reload
          expect(user_phone.confirmed?).to be_falsey
          expect(user_phone.notifications.count).to eq 1
          expect(user_phone.legacy?).to be_falsey
          expect(user_phone.confirmation_code).to_not eq "ccccc"
          expect(user_phone.resend_confirmation?).to be_falsey
        end
      end
      context "already confirmed?" do
        let(:user_phone) { FactoryBot.create(:user_phone_confirmed, user: current_user, phone: phone) }
        it "does not resend" do
          # Shouldn't actually effect #resend_confirmation?, but still...
          user_phone.update_column :updated_at, Time.current - 5.minutes
          user_phone.reload
          expect(user_phone.confirmed?).to be_truthy
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! {
            expect {
              patch "#{base_url}/#{user_phone.to_param}", params: {resend_confirmation: true}
            }.to_not change(Notification, :count)
          }
          expect(flash[:error]).to be_present

          current_user.reload
          expect(current_user.user_phones.count).to eq 1
          expect(current_user.phone_waiting_confirmation?).to be_falsey

          user_phone.reload
          expect(user_phone.confirmed?).to be_truthy
          expect(user_phone.notifications.count).to eq 0
        end
      end
      context "different users phone" do
        let(:user_phone) { FactoryBot.create(:user_phone, phone: phone) }
        it "does not resend" do
          user_phone.update_column :updated_at, Time.current - 5.minutes
          user_phone.reload
          expect(user_phone.resend_confirmation?).to be_truthy
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! {
            expect {
              patch "#{base_url}/#{user_phone.to_param}", params: {resend_confirmation: true}
            }.to raise_error(ActiveRecord::RecordNotFound)
          }
          current_user.reload
          expect(current_user.user_phones.count).to eq 0
          expect(current_user.phone_waiting_confirmation?).to be_falsey
        end
      end
    end

    describe "destroy" do
      it "removes the user_phone" do
        user_phone.reload
        current_user.reload
        expect(current_user.user_phones.count).to eq 1
        expect {
          delete "#{base_url}/#{user_phone.to_param}"
        }.to change(UserPhone, :count).by(-1)
        expect(flash[:success]).to be_present

        current_user.reload
        expect(current_user.user_phones.count).to eq 0
      end
      context "not users phone" do
        let!(:user_phone2) { FactoryBot.create(:user_phone) }
        it "does not remove the user_phone" do
          user_phone.reload
          current_user.reload
          expect(current_user.user_phones.count).to eq 1
          expect {
            delete "#{base_url}/#{user_phone2.to_param}"
          }.to raise_error(ActiveRecord::RecordNotFound)

          current_user.reload
          expect(current_user.user_phones.count).to eq 1

          expect(UserPhone.find(user_phone2.id)).to be_present
        end
      end
    end
  end
end
