module API
  module V3
    class Search < API::Base
      helpers do
        params :non_serial_search_params do
          optional :query, type: String, desc: "Full text search"
          optional :manufacturer, type: String
          optional :colors, type: Array
          optional :location, type: String, desc: "Location for proximity search", default: "IP"
          optional :distance, type: String, desc: "Distance in miles from `location` for proximity search", default: 10
          optional :stolenness, type: String, values: %w(non stolen proximity all) + [""], default: "stolen"
          optional :query_items, type: Array, desc: "Our Fancy select query items, DO NOT USE, may change without notice", documentation: { hidden: true }
        end
        params :search do
          optional :serial, type: String, desc: "Serial, homoglyph matched"
          use :non_serial_search_params
        end

        def interpreted_params
          Bike.searchable_interpreted_params(params, ip: forwarded_ip_address)
        end

        def serialized_bikes_results(paginated_bikes)
          ActiveModel::ArraySerializer.new(paginated_bikes,
                                           each_serializer: BikeV2Serializer, root: "bikes")
        end

        def forwarded_ip_address
          request.env["HTTP_X_FORWARDED_FOR"].split(",")[0] if request.env["HTTP_X_FORWARDED_FOR"]
        end
      end
      resource :search, desc: "Searching for bikes" do
        desc "Search for bikes", {
          notes: <<-NOTE,
            `stolenness` is the sort of bikes to match. "**all**": every bike, "**non**": only not-stolen, "**stolen**": all stolen, "**proximity**": only stolen within `distance` of included `location`.

            `location` is ignored unless `stolenness` is "**proximity**"

            `location` can be an address, zipcode, city, or latitude,longitude. e.g. "**210 NW 11th Ave, Portland, OR**", "**60647**", "**Chicago, IL**", or "**45.521728,-122.67326**"

            If `location` is "**IP**" (the default), the location is determined via geolocation of your IP address.
          NOTE
        }
        paginate
        params do
          use :search
          optional :per_page, type: Integer, default: 25, desc: "Bikes per page (max 100)"
        end
        get "/" do
          serialized_bikes_results(paginate Bike.search(interpreted_params))
        end

        desc "Count of bikes matching search", {
          notes: <<-NOTE,
            Include all the options passed in your search. This endpoint accepts the same parameters as the root `/search` endpoint.

            Responds with a hash of the total number of bikes matching your search for each type.

            `proximity` is the count of matching stolen bikes within the proximity of your search.

            ```javascript
            {
              "proximity": 19,
              "stolen": 100,
              "non": 111
            }
            ```

            *The `stolenness` paramater is ignored but allowed here for consistency*
          NOTE
        }
        params do
          use :search
        end
        get "/count" do
          count_interpreted_params = Bike.searchable_interpreted_params(params.merge(stolenness: "proximity"), ip: forwarded_ip_address)
          {
            proximity: Bike.search(count_interpreted_params).count,
            stolen: Bike.search(count_interpreted_params.merge(stolenness: "stolen")).count,
            non: Bike.search(count_interpreted_params.merge(stolenness: "non")).count,
          }
        end

        desc "Search close serials", {
          notes: <<-NOTE,
            This endpoint accepts the same parameters as the root `/search` endpoint.

            It returns matches that are off of the submitted `serial` by less than 3 characters (postgres levenshtein, if you're curious).
          NOTE
        }
        paginate
        params do
          requires :serial, type: String, desc: "Serial, homoglyph matched"
          use :non_serial_search_params
          optional :per_page, type: Integer, default: 25, desc: "Bikes per page (max 100)"
        end
        get "/close_serials" do
          close_serials = Bike.search_close_serials(interpreted_params)
          serialized_bikes_results(paginate(close_serials))
        end

        desc "Search by serial number (partially matching)", {
               notes: <<-NOTE,
                This endpoint accepts the same parameters as the root `/search`
                endpoint.

                It returns bikes with partially-matching serial numbers to the
                requested serial.

                If space-separated, multiple serial number stems can be provided
                under the `serial` param and partial matches for all will be
                returned.
               NOTE
             }
        paginate
        params do
          requires :serial, type: String, desc: "Serial, homoglyph matched"
          use :non_serial_search_params
          optional :per_page, type: Integer, default: 25, desc: "Bikes per page (max 100)"
        end
        get "/partial_serials" do
          serial_numbers =
            params[:serial].to_s.split(" ")

          search_queries =
            serial_numbers
              .flat_map { |serial| interpreted_params.merge(serial: serial) }

          results =
            search_queries
              .flat_map { |query| Bike.search_partial_serials(query) }

          serialized_bikes_results(paginate(results))
        end

        desc "Search external registries", {
               notes: <<-NOTE,
                 This endpoint accepts a serial number and searches external
                 bike registries for it.

                 If exact matches are found, only those will be returned.
                 If no exact matches are found, partial matches are returned.
               NOTE
             }
        paginate
        params do
          requires :serial, type: String, desc: "Serial, homoglyph matched"
          use :non_serial_search_params
          optional :per_page, type: Integer, default: 25, desc: "Bikes per page (max 100)"
        end
        get "/external_registries" do
          bikes = ExternalRegistryBike.find_or_search_registry_for(
            serial_number: interpreted_params[:raw_serial],
          )

          ActiveModel::ArraySerializer.new(
            paginate(bikes),
            each_serializer: ExternalRegistryBikeV3Serializer,
            root: "bikes",
          )
        end
      end
    end
  end
end
