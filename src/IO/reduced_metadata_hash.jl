"""Hash the normalized JSON wire representation of reduced bundle metadata."""
reduced_metadata_hash(x) = canonical_hash(_plain(JSON3.read(JSON3.write(x))))
