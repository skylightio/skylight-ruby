require 'spec_helper'

module Skylight
  describe "Normalizers", "request.faraday", :faraday, :agent do

    it "normalizes GET" do
      url = URI::HTTPS.new("https", nil, "maps.googleapis.com", 443, nil, "/maps/api/geocode/json", nil, "address=Oxford+University%2C+uk&sensor=false", nil)

      category, title, description = normalize({
        url: url,
        method: :get,
        name: "request.faraday"
      })
      
      expect(category).to    eq("api.http.get")
      expect(title).to       eq("Faraday")
      expect(description).to eq("GET maps.googleapis.com")
    end
  end
end
