require "rails_helper"

RSpec.describe StolenBikeListing, type: :model do
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color) }

  describe "amount" do
    let(:stolen_bike_listing) { FactoryBot.build(:stolen_bike_listing, amount_cents: 12_000, currency: "MXN") }
    it "is in pesos" do
      expect(stolen_bike_listing.amount_formatted).to eq "$120.00"
    end
  end

  describe "searchable" do
    let(:interpreted_params) { StolenBikeListing.searchable_interpreted_params(query_params) }
    context "color_ids of primary, secondary and tertiary" do
      let(:color2) { FactoryBot.create(:color) }
      let(:stolen_bike_listing1) { FactoryBot.create(:stolen_bike_listing, primary_frame_color: color, listed_at: Time.current - 3.months) }
      let(:stolen_bike_listing2) { FactoryBot.create(:stolen_bike_listing, secondary_frame_color: color, tertiary_frame_color: color2, listed_at: Time.current - 2.weeks) }
      let(:stolen_bike_listing3) { FactoryBot.create(:stolen_bike_listing, tertiary_frame_color: color, manufacturer: manufacturer) }
      let(:all_color_ids) do
        [
          stolen_bike_listing1.primary_frame_color_id,
          stolen_bike_listing2.primary_frame_color_id,
          stolen_bike_listing3.primary_frame_color_id,
          stolen_bike_listing1.secondary_frame_color_id,
          stolen_bike_listing2.secondary_frame_color_id,
          stolen_bike_listing3.secondary_frame_color_id,
          stolen_bike_listing1.tertiary_frame_color_id,
          stolen_bike_listing2.tertiary_frame_color_id,
          stolen_bike_listing3.tertiary_frame_color_id
        ]
      end
      before do
        expect(all_color_ids.count(color.id)).to eq 3 # Each bike has color only once
      end
      context "single color" do
        let(:query_params) { {colors: [color.id], stolenness: "all"} }
        it "matches bikes with the given color" do
          expect(stolen_bike_listing1.listing_order < stolen_bike_listing2.listing_order).to be_truthy
          expect(stolen_bike_listing2.listing_order < stolen_bike_listing3.listing_order).to be_truthy
          expect(StolenBikeListing.search(interpreted_params).pluck(:id)).to eq([stolen_bike_listing3.id, stolen_bike_listing2.id, stolen_bike_listing1.id])
        end
      end
      context "second color" do
        let(:query_params) { {colors: [color.id, color2.id], stolenness: "all"} }
        it "matches just the bike with both colors" do
          expect(StolenBikeListing.search(interpreted_params).pluck(:id)).to eq([stolen_bike_listing2.id])
        end
      end
      context "and manufacturer_id" do
        let(:query_params) { {colors: [color.id], manufacturer: manufacturer.id, stolenness: "all"} }
        it "matches just the bike with the matching manufacturer" do
          expect(StolenBikeListing.search(interpreted_params).pluck(:id)).to eq([stolen_bike_listing3.id])
        end
      end
    end
  end

  describe "updated_photo_folder" do
    let(:stolen_bike_listing) { StolenBikeListing.new(data: {photo_folder: photo_folder}) }
    let(:photo_folder) { "Nov 20 2020_006" }
    it "puts out expected thing" do
      expect(stolen_bike_listing.updated_photo_folder).to eq "2020/11/20_006"
    end
    context "different date" do
      let(:photo_folder) { "aug 23 2020" }
      it "deals with that too" do
        expect(stolen_bike_listing.updated_photo_folder).to eq "2020/8/23"
      end
    end
    context "weird date" do
      let(:photo_folder) { "july7_2020_2" }
      it "deals with that too" do
        expect(stolen_bike_listing.updated_photo_folder).to eq "2020/7/7_2"
      end
    end
    context "other weird shit" do
      let(:photo_folder) { "Feb 14 2021_OMFG" }
      it "deals with that too" do
        expect(stolen_bike_listing.updated_photo_folder).to eq "2021/2/14_OMFG"
      end
    end
    context "empty" do
      let(:photo_folder) { "" }
      it "handles it" do
        expect(stolen_bike_listing.updated_photo_folder).to be_blank
      end
    end
  end
end
