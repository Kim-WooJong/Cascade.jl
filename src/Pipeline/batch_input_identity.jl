"""Pin cheap source signatures and physical identity, without hashing large ROOT payloads."""
function batch_input_identity(path)
    st = stat(path)
    return Dict("signature" => file_signature(path), "realpath" => realpath(path),
        "device" => string(st.device), "inode" => string(st.inode))
end
