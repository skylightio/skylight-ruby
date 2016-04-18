module SpecHelper

  def normalizers
    @normalizers ||= Skylight::Normalizers.build(config)
  end

  # avoid polluting allocation counter
  BEHAVE_LIKE = "it should behave like".freeze
  PAYLOAD = {}.freeze

  def normalize(name=nil, payload=nil)
    process_normalize(:normalize, name, payload)
  end

  def normalize_after(name=nil, payload=nil)
    process_normalize(:normalize_after, name, payload)
  end

  private

    def process_normalize(meth, name, payload)
      if Hash === name
        payload = name
        name = nil
      end

      group = self.class.metadata
      group = group[:parent_example_group] if group[:description].start_with?(BEHAVE_LIKE)

      description = group[:description_args]
      name ||= description[1] ? description[1] : description[0]

      if meth == :normalize_after
        normalizers.normalize_after(trace, 0, name, payload)
      else
        normalizers.normalize(trace, name, payload)
      end
    end

end
