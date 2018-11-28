require "spec_helper"

describe "Organized::MessagesController" do
  include_context :geocoder_default_location
  let(:organization) { FactoryGirl.create(:organization, is_paid: false, geolocated_emails: true) }
  let(:base_url) { "/o/#{organization.to_param}/messages" }
  before { set_current_user(user, request_spec: true) if user.present? }

  describe "messages root" do
    let(:user) { FactoryGirl.create(:organization_member, organization: organization) }
    context "json" do
      it "returns empty" do
        get base_url, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq([])
        expect(response.headers['Access-Control-Allow-Origin']).not_to be_present
        expect(response.headers['Access-Control-Request-Method']).not_to be_present
      end
      context "with a message" do
        let!(:organization_message_1) { FactoryGirl.create(:organization_message, organization: organization, kind: "geolocated", created_at: Time.now - 1.hour) }
        let(:target) do
          {
            id: organization_message_1.id,
            kind: "geolocated",
            created_at: organization_message_1.created_at.to_i,
            lat: organization_message_1.latitude,
            lng: organization_message_1.longitude
          }
        end
        it "renders json, no cors present" do
          get base_url, format: :json
          expect(response.status).to eq(200)
          result = JSON.parse(response.body)
          expect(result.count).to eq 1
          expect(result.first).to eq target.as_json
          expect(response.headers['Access-Control-Allow-Origin']).not_to be_present
          expect(response.headers['Access-Control-Request-Method']).not_to be_present
        end
        context "with parameters" do
          let!(:organization_message_2) { FactoryGirl.create(:organization_message, organization: organization, kind: "geolocated", created_at: Time.now - 1.day) }
          it "returns the matches" do
            get "#{base_url}?per_page=1&page=1", format: :json
            expect(response.status).to eq(200)
            result = JSON.parse(response.body)
            expect(result.count).to eq 1
            expect(result.first).to eq target.as_json
            expect(response.header["Total"]).to eq("2")
            expect(response.header["link"]).to match(/#{base_url}/)
          end
        end
      end
    end
  end
end
