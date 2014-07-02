unless StringScanner.method_defined? :charpos
  class StringScanner
    def charpos
      if string.respond_to?(:byteslice)
        string.byteslice(0, pos).length
      else
        string.unpack("@0a#{pos}").first.force_encoding("UTF-8").length
      end
    end
  end
end