#!/usr/bin/env bash

# ==============================================================================
# POST-QUANTUM MODULE 2: SECURE MESSAGING & IDENTITY ENGINE (v8.5)
# Architecture: Hybrid KEM (X25519 + ML-KEM) + Encrypt-then-MAC + SPHINCS+ Identity
# Enhancements: OpenPGP Packet Serialization, Literal Enclaves, Traffic Padding
# ==============================================================================
set -e
set -o pipefail

PROVIDER_ARGS=("-provider" "default" "-provider" "oqsprovider")

# --- EXHAUSTIVE ALGORITHM LISTS ---
LIST_KEMS=(
    "MLKEM512" "MLKEM768" "MLKEM1024"
    "p256_mlkem512" "p384_mlkem768" "p521_mlkem1024" 
    "frodo640aes" "p256_frodo640aes" "frodo640shake" "p256_frodo640shake" 
    "frodo976aes" "p384_frodo976aes" "frodo976shake" "p384_frodo976shake" 
    "frodo1344aes" "p521_frodo1344aes" "frodo1344shake" "p521_frodo1344shake"
)

LIST_SIGS=(
    "MLDSA87" "MLDSA65" "MLDSA44" 
    "SLH-DSA-SHA2-128s" "SLH-DSA-SHA2-128f" "SLH-DSA-SHA2-256s" "SLH-DSA-SHA2-256f"
    "SLH-DSA-SHAKE-128s" "SLH-DSA-SHAKE-128f" "SLH-DSA-SHAKE-256s" "SLH-DSA-SHAKE-256f"
    "falcon1024" "falcon512" "p384_mldsa65" "p521_mldsa87"
)

LIST_CIPHERS=("aes-256-cbc" "aes-256-ctr" "chacha20" "camellia-256-cbc")

LIST_DIGESTS=(
    "SHA256" "SHA512" "SHA512-224" "SHA512-256"
    "SHA3-224" "SHA3-256" "SHA3-384" "SHA3-512"
    "SHAKE128" "SHAKE256"
    "KECCAK-224" "KECCAK-256" "KECCAK-384" "KECCAK-512"
    "BLAKE2s256" "BLAKE2b512"
    "SM3" "RIPEMD160" "SHA1" "MD5"
)

# --- HELPER ROUTINES ---
select_variant() {
    local -n list=$1
    for i in "${!list[@]}"; do
        echo "$((i+1))) ${list[$i]}" >&2
    done
    local choice
    while true; do
        read -p "Selection [1-${#list[@]}]: " choice >&2
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#list[@]}" ]; then
            echo "${list[$((choice-1))]}"
            return
        else
            echo "[!] Invalid input." >&2
        fi
    done
}

extract_block() {
    local file=$1
    local marker=$2
    sed -n "/---${marker}---/,/^---/p" "$file" | grep -v "^---" | base64 -d
}

if ! command -v xxd &> /dev/null; then
    echo "[-] CRITICAL: 'xxd' is not installed. Please run: sudo apt install xxd"
    exit 1
fi

clear
echo "====================================================================="
echo "        POST-QUANTUM E2EE MESSAGING ENGINE (v8.5)"
echo "====================================================================="
echo "1) Generate New Identity Keyring (Keys to keep & share)"
echo "2) Generate Cryptographic Fingerprints (For GitHub/Bio)"
echo "3) Encrypt & Sign a Message (Produces Serialized Armor Package)"
echo "4) Decrypt & Verify a Message (Parses Serialized Armor Package)"
echo "====================================================================="
read -p "Select Action [1-4]: " action_choice

case "$action_choice" in
    1)
        echo -e "\n--- GENERATE NEW IDENTITY ---"
        read -p "Enter a username for this identity (e.g., alice): " username
        SAFE_USER=$(echo "$username" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
        ID_DIR="./identity_${SAFE_USER}"
        
        mkdir -p "${ID_DIR}/private" "${ID_DIR}/public"
        
        echo -e "\n[1/3] Generating Classical X25519 Routing Key (For Hybrid Safety Net)..."
        openssl genpkey "${PROVIDER_ARGS[@]}" -algorithm X25519 -out "${ID_DIR}/private/x25519.priv"
        openssl pkey "${PROVIDER_ARGS[@]}" -in "${ID_DIR}/private/x25519.priv" -pubout -out "${ID_DIR}/public/x25519.pub"
        
        echo -e "\n[2/3] Select Post-Quantum KEM Mechanism (For Hybrid Safety Net):"
        KEM_ALG=$(select_variant LIST_KEMS)
        openssl genpkey "${PROVIDER_ARGS[@]}" -algorithm "$KEM_ALG" -out "${ID_DIR}/private/pq_kem.priv"
        openssl pkey "${PROVIDER_ARGS[@]}" -in "${ID_DIR}/private/pq_kem.priv" -pubout -out "${ID_DIR}/public/pq_kem.pub"
        
        echo -e "\n[3/3] Select Identity Signature Algorithm (Recommend SLH-DSA for long-term):"
        SIG_ALG=$(select_variant LIST_SIGS)
        openssl genpkey "${PROVIDER_ARGS[@]}" -algorithm "$SIG_ALG" -out "${ID_DIR}/private/sig.priv"
        openssl pkey "${PROVIDER_ARGS[@]}" -in "${ID_DIR}/private/sig.priv" -pubout -out "${ID_DIR}/public/sig.pub"
        
        echo -e "\n\e[32m[+] Identity Created Successfully!\e[0m"
        echo "Private Keystore: ${ID_DIR}/private/ (Keep this secure!)"
        echo "Public Keystore:  ${ID_DIR}/public/  (Send this folder to your contacts)"
        ;;

    2)
        echo -e "\n--- GENERATE CRYPTOGRAPHIC FINGERPRINTS ---"
        read -e -p "Path to your Public Keyring folder (e.g., ./identity_alice/public): " PUB_DIR
        
        if [ ! -d "$PUB_DIR" ]; then echo "[-] Folder not found."; exit 1; fi
        
        echo -e "\n\e[36mCopy these short fingerprints to your GitHub, Twitter, or Website:\e[0m"
        echo "------------------------------------------------------------------"
        if [ -f "${PUB_DIR}/sig.pub" ]; then
            FINGERPRINT=$(openssl dgst "${PROVIDER_ARGS[@]}" -sha256 -c "${PUB_DIR}/sig.pub" | awk -F'= ' '{print $2}')
            echo "[IDENTITY] Signature Key:  $FINGERPRINT"
        fi
        if [ -f "${PUB_DIR}/pq_kem.pub" ]; then
            FINGERPRINT=$(openssl dgst "${PROVIDER_ARGS[@]}" -sha256 -c "${PUB_DIR}/pq_kem.pub" | awk -F'= ' '{print $2}')
            echo "[ROUTING]  Post-Quantum:   $FINGERPRINT"
        fi
        if [ -f "${PUB_DIR}/x25519.pub" ]; then
            FINGERPRINT=$(openssl dgst "${PROVIDER_ARGS[@]}" -sha256 -c "${PUB_DIR}/x25519.pub" | awk -F'= ' '{print $2}')
            echo "[ROUTING]  Classical Curve: $FINGERPRINT"
        fi
        echo "------------------------------------------------------------------"
        ;;
        
    3)
        echo -e "\n--- ENCRYPT & SIGN MESSAGE ---"
        read -e -p "Path to YOUR Private Keyring folder (e.g., ./identity_alice/private): " MY_PRIV_DIR
        read -e -p "Path to RECIPIENT'S Public Keyring folder (e.g., ./identity_bob/public): " REC_PUB_DIR
        read -e -p "Path to the raw message file to send: " MSG_FILE
        
        if [ ! -f "$MSG_FILE" ]; then echo "[-] Message file not found."; exit 1; fi

        echo -e "\nSelect Symmetric Payload Cipher:"
        CIPHER=$(select_variant LIST_CIPHERS)
        
        echo -e "\nSelect Digest Hash for Identity Signature:"
        HASH_ALG=$(select_variant LIST_DIGESTS)
        
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        TEMP_WORK=$(mktemp -d)
        
        echo "[*] 1/8 Constructing Sealed Literal Data Enclave & Applying Traffic Padding..."
        ORIG_NAME=$(basename "$MSG_FILE")
        ORIG_SIZE=$(stat -c%s "$MSG_FILE")
        
        # Enveloping Metadata
        echo "$ORIG_NAME" > "${TEMP_WORK}/enclave.raw"
        echo "$ORIG_SIZE" >> "${TEMP_WORK}/enclave.raw"
        cat "$MSG_FILE" >> "${TEMP_WORK}/enclave.raw"
        
        # Uniform block size enforcement (Align to 4096-byte boundaries to defeat file-size fingerprinting)
        CUR_SIZE=$(stat -c%s "${TEMP_WORK}/enclave.raw")
        PAD_LEN=$(( (4096 - (CUR_SIZE % 4096)) % 4096 ))
        if [ $PAD_LEN -gt 0 ]; then
            dd if=/dev/zero bs=1 count=$PAD_LEN >> "${TEMP_WORK}/enclave.raw" 2>/dev/null
        fi

        echo "[*] 2/8 Encapsulating Classical X25519 Secret..."
        openssl pkeyutl "${PROVIDER_ARGS[@]}" -derive -inkey "${MY_PRIV_DIR}/x25519.priv" -peerkey "${REC_PUB_DIR}/x25519.pub" -out "${TEMP_WORK}/classic_secret.bin"
        
        echo "[*] 3/8 Encapsulating Post-Quantum KEM Secret..."
        openssl pkeyutl "${PROVIDER_ARGS[@]}" -encap -pubin -inkey "${REC_PUB_DIR}/pq_kem.pub" -out "${TEMP_WORK}/pq_payload.encap" -secret "${TEMP_WORK}/pq_secret.bin"
        
        echo "[*] 4/8 Deriving Hybrid Cryptographic Master Keys via SHA-512 KDF..."
        cat "${TEMP_WORK}/classic_secret.bin" "${TEMP_WORK}/pq_secret.bin" | openssl dgst -sha512 -binary > "${TEMP_WORK}/master_secret.bin"
        HEX_KEY=$(xxd -p -c 64 "${TEMP_WORK}/master_secret.bin" | cut -c 1-64)
        MAC_KEY=$(xxd -p -c 64 "${TEMP_WORK}/master_secret.bin" | cut -c 65-128)
        
        HEX_IV=$(openssl rand -hex 16)
        
        echo "[*] 5/8 Executing Encrypt-then-MAC (AEAD) Payload Protection..."
        openssl enc -"${CIPHER}" -K "$HEX_KEY" -iv "$HEX_IV" -in "${TEMP_WORK}/enclave.raw" -out "${TEMP_WORK}/payload.cipher"
        openssl dgst -sha256 -mac HMAC -macopt hexkey:"$MAC_KEY" -binary -out "${TEMP_WORK}/payload.tag" "${TEMP_WORK}/payload.cipher"
        
        echo "[*] 6/8 Signing Integrity Bundle with Post-Quantum Identity..."
        cp "${MY_PRIV_DIR}/../public/x25519.pub" "${TEMP_WORK}/sender_x25519.pub"
        cat "${TEMP_WORK}/payload.cipher" <(echo "$HEX_IV") "${TEMP_WORK}/payload.tag" "${TEMP_WORK}/sender_x25519.pub" > "${TEMP_WORK}/temp.bundle"
        
        if [[ "$HASH_ALG" == *"SHAKE"* ]]; then
            openssl dgst "${PROVIDER_ARGS[@]}" -"$HASH_ALG" -xoflen 64 -binary -out "${TEMP_WORK}/payload.hash" "${TEMP_WORK}/temp.bundle"
        else
            openssl dgst "${PROVIDER_ARGS[@]}" -"$HASH_ALG" -binary -out "${TEMP_WORK}/payload.hash" "${TEMP_WORK}/temp.bundle"
        fi
        openssl pkeyutl "${PROVIDER_ARGS[@]}" -sign -rawin -in "${TEMP_WORK}/payload.hash" -inkey "${MY_PRIV_DIR}/sig.priv" -out "${TEMP_WORK}/payload.sig"
        
        echo "[*] 7/8 Serializing Multi-Packet Cryptographic Stream into ASCII Armor..."
        OUT_FILE="./msg_${TIMESTAMP}.pqp"
        {
            echo "-----BEGIN PQC PACKET STREAM-----"
            echo "Version: PQC-8.5"
            echo "Cipher: ${CIPHER}"
            echo "Digest: ${HASH_ALG}"
            echo "IV: ${HEX_IV}"
            echo "---ENCAP---"
            base64 -w 0 "${TEMP_WORK}/pq_payload.encap"; echo ""
            echo "---SENDER-PUB---"
            base64 -w 0 "${TEMP_WORK}/sender_x25519.pub"; echo ""
            echo "---TAG---"
            base64 -w 0 "${TEMP_WORK}/payload.tag"; echo ""
            echo "---SIG---"
            base64 -w 0 "${TEMP_WORK}/payload.sig"; echo ""
            echo "---CIPHERTEXT---"
            base64 -w 0 "${TEMP_WORK}/payload.cipher"; echo ""
            echo "-----END PQC PACKET STREAM-----"
        } > "$OUT_FILE"
        
        echo "[*] 8/8 Sanitizing Ephemeral Core Memory..."
        rm -rf "$TEMP_WORK"
        
        echo -e "\n\e[32m[+] Packet Stream Encrypted & Serialized Successfully!\e[0m"
        echo "Exclusively share this single armored file with the recipient: $OUT_FILE"
        ;;
        
    4)
        echo -e "\n--- DECRYPT & VERIFY MESSAGE ---"
        read -e -p "Path to YOUR Private Keyring folder (e.g., ./identity_bob/private): " MY_PRIV_DIR
        read -e -p "Path to SENDER'S Public Keyring folder (e.g., ./identity_alice/public): " SENDER_PUB_DIR
        read -e -p "Path to the received ASCII Armor package (.pqp file): " PACKET_FILE
        
        if [ ! -f "$PACKET_FILE" ]; then echo "[-] Package file not found."; exit 1; fi
        
        TEMP_WORK=$(mktemp -d)
        
        echo "[*] 1/6 Parsing Serialized Protocol Metadata & Stream Demultiplexing..."
        CIPHER=$(grep "^Cipher:" "$PACKET_FILE" | awk '{print $2}')
        HASH_ALG=$(grep "^Digest:" "$PACKET_FILE" | awk '{print $2}')
        HEX_IV=$(grep "^IV:" "$PACKET_FILE" | awk '{print $2}')
        
        extract_block "$PACKET_FILE" "ENCAP" > "${TEMP_WORK}/pq_payload.encap"
        extract_block "$PACKET_FILE" "SENDER-PUB" > "${TEMP_WORK}/sender_x25519.pub"
        extract_block "$PACKET_FILE" "TAG" > "${TEMP_WORK}/payload.tag"
        extract_block "$PACKET_FILE" "SIG" > "${TEMP_WORK}/payload.sig"
        extract_block "$PACKET_FILE" "CIPHERTEXT" > "${TEMP_WORK}/payload.cipher"

        echo "[*] 2/6 Verifying Post-Quantum Cryptographic Identity Signature..."
        cat "${TEMP_WORK}/payload.cipher" <(echo "$HEX_IV") "${TEMP_WORK}/payload.tag" "${TEMP_WORK}/sender_x25519.pub" > "${TEMP_WORK}/temp.bundle"
        
        if [[ "$HASH_ALG" == *"SHAKE"* ]]; then
            openssl dgst "${PROVIDER_ARGS[@]}" -"$HASH_ALG" -xoflen 64 -binary -out "${TEMP_WORK}/payload.hash" "${TEMP_WORK}/temp.bundle"
        else
            openssl dgst "${PROVIDER_ARGS[@]}" -"$HASH_ALG" -binary -out "${TEMP_WORK}/payload.hash" "${TEMP_WORK}/temp.bundle"
        fi
        
        if openssl pkeyutl "${PROVIDER_ARGS[@]}" -verify -rawin -in "${TEMP_WORK}/payload.hash" -sigfile "${TEMP_WORK}/payload.sig" -pubin -inkey "${SENDER_PUB_DIR}/sig.pub"; then
            echo -e "\e[32m    -> IDENTITY VALID: Genuine sender confirmed.\e[0m"
        else
            echo -e "\e[31m[-] CRITICAL: Signature Verification Failed! Package intercepted or spoofed.\e[0m"
            rm -rf "$TEMP_WORK"
            exit 1
        fi
        
        echo "[*] 3/6 Executing Hybrid Decapsulation (Classical X25519 + ML-KEM)..."
        openssl pkeyutl "${PROVIDER_ARGS[@]}" -derive -inkey "${MY_PRIV_DIR}/x25519.priv" -peerkey "${TEMP_WORK}/sender_x25519.pub" -out "${TEMP_WORK}/classic_secret.bin"
        openssl pkeyutl "${PROVIDER_ARGS[@]}" -decap -inkey "${MY_PRIV_DIR}/pq_kem.priv" -in "${TEMP_WORK}/pq_payload.encap" -out "${TEMP_WORK}/pq_secret.bin"
        
        echo "[*] 4/6 Performing Cryptographic Integrity Checks (HMAC Verification)..."
        cat "${TEMP_WORK}/classic_secret.bin" "${TEMP_WORK}/pq_secret.bin" | openssl dgst -sha512 -binary > "${TEMP_WORK}/master_secret.bin"
        HEX_KEY=$(xxd -p -c 64 "${TEMP_WORK}/master_secret.bin" | cut -c 1-64) 
        MAC_KEY=$(xxd -p -c 64 "${TEMP_WORK}/master_secret.bin" | cut -c 65-128) 
        
        openssl dgst -sha256 -mac HMAC -macopt hexkey:"$MAC_KEY" -binary -out "${TEMP_WORK}/calculated.tag" "${TEMP_WORK}/payload.cipher"
        
        if cmp -s "${TEMP_WORK}/payload.tag" "${TEMP_WORK}/calculated.tag"; then
            echo -e "\e[32m    -> AEAD INTEGRITY VALID: Stream tampering checks passed.\e[0m"
        else
            echo -e "\e[31m[-] CRITICAL: Authentication Tag Mismatch! Packet structural contents manipulated.\e[0m"
            rm -rf "$TEMP_WORK"
            exit 1
        fi
        
        echo "[*] 5/6 Decrypting Payload and Accessing Literal Enclave Enclosure..."
        openssl enc -d -"${CIPHER}" -K "$HEX_KEY" -iv "$HEX_IV" -in "${TEMP_WORK}/payload.cipher" -out "${TEMP_WORK}/enclave.dec"
        
        # Unpacking Literal Enclave and stripping out padding
        TARGET_FILENAME=$(sed -n '1p' "${TEMP_WORK}/enclave.dec")
        TARGET_FILESIZE=$(sed -n '2p' "${TEMP_WORK}/enclave.dec")
        
        # Calculate exactly where text payload begins inside stream header block
        HEADER_LINES_OFFSET=$(awk 'NR<=2 {print length($0)+1}' "${TEMP_WORK}/enclave.dec" | awk '{s+=$1} END {print s}')
        
        tail -c +"$((HEADER_LINES_OFFSET + 1))" "${TEMP_WORK}/enclave.dec" | head -c "$TARGET_FILESIZE" > "./decrypted_${TARGET_FILENAME}"
        
        echo "[*] 6/6 Purging temporary file handles..."
        rm -rf "$TEMP_WORK"
        
        echo -e "\n\e[32m[+] Packet Stream Successfully Decoded and Restored!\e[0m"
        echo "Original File Name: $TARGET_FILENAME ($TARGET_FILESIZE bytes)"
        echo "Extracted plain payload file destination: ./decrypted_${TARGET_FILENAME}"
        ;;
        
    *)
        echo "[-] Invalid Selection."
        exit 1
        ;;
esac
