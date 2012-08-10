# Direwolf Agent

Collect instrumentation from a rails application and send it off to the
direwolf servers.

## Traces

An conceptual overview of a trace.

  * Trace ID (UUID)
  * Tiers
    * Name
    * Spans (max 256 unique per tier)
      * Category (multi-level, example: cache.redis)
      * Description
      * Annotations
