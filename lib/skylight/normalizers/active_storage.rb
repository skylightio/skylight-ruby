module Skylight
  module Normalizers
    class ActiveStorage < Normalizer
      # rubocop:disable Layout/AlignHash # Ideally we'd be able to switch to EnforcedColonStyle: table temporarily
      TITLES = {
        "preview.active_storage"                    => "Preview",
        "transform.active_storage"                  => "Transform",
        "service_download.active_storage"           => "Download",
        "service_upload.active_storage"             => "Upload",
        "service_streaming_download.active_storage" => "Streaming Download",
        "service_download_chunk.active_storage"     => "Download Chunk",
        "service_delete.active_storage"             => "Delete",
        "service_delete_prefixed.active_storage"    => "Delete Prefixed",
        "service_exist.active_storage"              => "Exist",
        "service_url.active_storage"                => "Url"
      }.freeze
      # rubocop:enable Layout/AlignHash

      TITLES.each_key do |key|
        register key
      end

      def normalize(_trace, name, _payload)
        title = ["ActiveStorage", TITLES[name]].join(" ")

        cat = "app.#{name.split('.').reverse.join('.')}"

        [cat, title, nil]
      end
    end
  end
end
