require "rails_helper"

RSpec.describe UserEmbedsController, type: :controller do
  describe "show" do
    it "renders the page if username is found" do
      user = FactoryBot.create(:user, show_bikes: true)
      ownership = FactoryBot.create(:ownership, user_id: user.id, current: true)
      get :show, params: {id: user.username}
      expect(response.code).to eq("200")
      expect(assigns(:bikes).first).to eq(ownership.bike)
      expect(assigns(:bikes).count).to eq(1)
      expect(response.headers["X-Frame-Options"]).to be_blank
    end

    it "renders the most recent bikes with images if it doesn't find the user" do
      public_image = FactoryBot.create(:public_image)
      bike = public_image.imageable
      allow_any_instance_of(Bike).to receive(:public_images) { [public_image] }
      bike.save && bike.reload
      expect(bike.thumb_path).to be_present
      get :show, params: {id: "NOT A USER"}
      expect(response.code).to eq("200")
      expect(assigns(:bikes).count).to eq(1)
      expect(response.headers["X-Frame-Options"]).to be_blank
    end
  end
end
