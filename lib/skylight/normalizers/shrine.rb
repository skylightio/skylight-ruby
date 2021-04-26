module Skylight
  module Normalizers
    class Shrine < Normalizer
      TITLES = {
        "upload.shrine" => "Upload",
        "download.shrine" => "Download",
        "open.shrine" => "Open",
        "exists.shrine" => "Exists",
        "delete.shrine" => "Delete",
        "metadata.shrine" => "Metadata",
        "mime_type.shrine" => "MIME Type",
        "image_dimensions.shrine" => "Image Dimensions",
        "signature.shrine" => "Signature",
        "extension.shrine" => "Extension",
        "derivation.shrine" => "Derivation",
        "derivatives.shrine" => "Derivatives",
        "data_uri.shrine" => "Data URI",
        "remote_url.shrine" => "Remote URL"
      }.freeze

      TITLES.each_key { |key| register key }

      def normalize(_trace, name, _payload)
        title = ["Shrine", TITLES[name]].join(" ")

        cat = "app.#{name.split(".").reverse.join(".")}"

        [cat, title, nil]
      end
    end
  end
end
