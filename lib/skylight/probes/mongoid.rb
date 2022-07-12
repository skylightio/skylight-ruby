# Older versions of the mongoid uses the moped under-the-hood, while newer
# verions uses the official driver. It used to be that the the mongoid probe
# exists to detect and enable either one of those underlying probes, but at
# this point we no longer support moped, so this is now just an alias for the
# mongo probe.
require_relative "mongo"
