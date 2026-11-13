# Serial per-file windowed incremental selection (phase 1)

Opt in independently of file-chain handoff in the analysis TOML:

~~~toml
[execution]
windowed_selection = true # strict Bool; default false
memory_handoff = false   # independent, unchanged meaning
streaming_selection = false
column_readers = 1
decode_threads = 1
~~~

Both staged selection and memory handoff enter the same prepare_select /
execute_select_chunk implementation. Existing stream_window_events,
stream_window_bytes, stream_basket_bytes, stream_metadata_bytes,
stream_queue_bytes and stream_retained_bytes bound the window plan and owned
payload even though asynchronous streaming is disabled.

This is serial *within each file*, not full read/correct/fill fusion. The retained
selected EventTable still accumulates across the file for the unchanged file
checkpoint and optional correction/histogram handoff. There is no spool writer
or finer checkpoint granularity. Raw columns, progress and cached selected-object
spans have window scope, not file scope. The retained-table allowance is
conservative logical bytes, not an RSS guarantee.

Common-basket-boundary metadata planning prevents splitting/redecoding baskets.
Each window follows the ordinary SelectionProgress staged-column contract,
advancing only new cuts before a due group and retaining early-region failures
in later read masks. Canonical counter offsets are local to each window and
cached across columns. select_events finishes the same progress with one shared
Cutflow in original event order; no per-window floating-point reduction occurs.
Original entry indices are checked/offset and selected columns append in order.
An empty column_stages plan deliberately uses the conservative window reader.

Initial support is nominal NanoAOD with built-in source readers, no shape plan,
no theory/weight variations and no registered custom hooks. The configured
Cascade.Systematics.apply_corrections hook is allowed. Unsupported metadata
plans return a specific fallback reason before Events reads. Corrupt metadata,
budget excess, identity drift or errors after reading throw, with no catch/rerun.
The ROOT streamer header is checked before source opening; TTree fObjlen and
mapping identity are checked before Events reads; identity and table/event/cutflow
counts are checked again before file publication.

If windowed_selection is requested together with streaming_selection, the async
path is suppressed and ordinary selection runs with reason
streaming_selection_enabled. Requested decode/reader engines other than one also
use ordinary selection with specific reasons. Existing asynchronous behavior
when windowed_selection=false is unchanged. Window options retain their former
defaults and positivity validation. Execution flags do not become scientific
hash inputs; changed source code causes the existing one-time code-key change.

Diagnostics identify requested/effective/reason, window_count,
max_raw_window_bytes, decoded_baskets/skipped_baskets, and reader_engine=
UnROOT_window_legacy_basketarray_owned_copy. This is *not* the ordinary reusable
basket decoder and does not claim equivalent engine/performance.

## Narrow verification

Standalone stdlib-only test/windowed_selection/runtests.jl includes the real
progress/context/cut/event/table code with a synthetic owned-read IO boundary.
It compares whole vs split output bytes and ordered cutflow bits, tests empty
windows, no cuts/objects, early retained failures, output-only materialization,
stale object spans, canonical counter caching, strict Bool/inactive profiles and
engine conflict fallback. It does not establish ROOT integration, 100 GB parity,
performance, Linux source-identity behavior or full package integration.

The authorized local Julia version is 1.12.6; historical remote tests used
1.12.2. No remote validation, ROOT reads, package installation or full package
precompile was performed for this lane.


## Object-aware pre-read reservation

The metadata-only reservation uses checked Int128 arithmetic:

    D + 16*n*B + 4*n                 # existing planner raw/counters/offsets
      + 17*n + cld(n,8)             # passed/active/needed/failed progress
      + 16*n*O                      # per-event object spans
      + 16*sum(object_element_bounds) # Int indices with 2x capacity/copy slack
      + 4096*(B+O+1)                # headers/empty-window fixed allowance

D is overlapping declared decoded basket bytes, B requested branches, n window
entries, O compiled objects. Object name/collection pairs come from cfg.objects
and must match sel.object_names in order. Each object, including multiple
categories of the same collection, is charged independently. Its element bound
is the minimum of sum(declared bytes)/sizeof(element type), rounded down, over
requested primitive jagged fields of its own collection. Whole-basket window
geometry makes declared bytes an upper bound on flat content bytes (trailers
only increase that bound). A byte-valued field remains conservative. No branch
payload is multiplied by unrelated objects.

Missing mapping/compatible jagged proof returns a specific unsupported reason
before Events reads; malformed geometry/negative bytes/overflow throws. Budget
excess throws with window_index, required_bytes and execution.stream_window_bytes;
no automatic budget increase or catch/replay. reserved_raw_window_bytes reports
the metadata high-water reservation. Existing actual owned-byte checks remain
before and after select_events. These are conservative logical/capacity bounds,
not an RSS guarantee. Neither defaults nor CompiledSelection fields changed.
