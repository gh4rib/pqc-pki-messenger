# ==============================================================================
# POST-QUANTUM MASTER PKI ENGINE v3.0 (Strict TLS 1.3 Compliant)
# ==============================================================================
set -e
set -o pipefail

PROVIDER_ARGS=("-provider" "default" "-provider" "oqsprovider")

# --- DIGEST MAPPING ARRAY ---
DIGESTS=(
    "SHA256" "SHA512" "SHA512-224" "SHA512-256"
    "SHA3-224" "SHA3-256" "SHA3-384" "SHA3-512"
    "SHAKE128" "SHAKE256"
    "KECCAK-224" "KECCAK-256" "KECCAK-384" "KECCAK-512"
    "BLAKE2s256" "BLAKE2b512"
)

# --- DIGITAL SIGNATURE ALGORITHMS (DSAs) ---
SIG_FAMILIES=("ML-DSA (NIST Standard)" "ML-DSA (Hybrids)" "SLH-DSA (SHA2 variants)" "SLH-DSA (SHAKE variants)" "Falcon / Falcon-Padded" "Alternative Candidates (Mayo, CROSS, OV, Snova, MQOM)")

LIST_MLDSA_STD=("MLDSA44" "MLDSA65" "MLDSA87")
LIST_MLDSA_HYB=("p256_mldsa44" "rsa3072_mldsa44" "p384_mldsa65" "p521_mldsa87")
LIST_SLHDSA_SHA2=("SLH-DSA-SHA2-128s" "SLH-DSA-SHA2-128f" "SLH-DSA-SHA2-192s" "SLH-DSA-SHA2-192f" "SLH-DSA-SHA2-256s" "SLH-DSA-SHA2-256f")
LIST_SLHDSA_SHAKE=("SLH-DSA-SHAKE-128s" "SLH-DSA-SHAKE-128f" "SLH-DSA-SHAKE-192s" "SLH-DSA-SHAKE-192f" "SLH-DSA-SHAKE-256s" "SLH-DSA-SHAKE-256f")
LIST_FALCON=("falcon512" "p256_falcon512" "rsa3072_falcon512" "falconpadded512" "p256_falconpadded512" "rsa3072_falconpadded512" "falcon1024" "p521_falcon1024" "falconpadded1024" "p521_falconpadded1024")
LIST_ALT_SIG=("mayo1" "p256_mayo1" "mayo2" "p256_mayo2" "mayo3" "p384_mayo3" "mayo5" "p521_mayo5" "CROSSrsdp128balanced" "OV_Is_pkc" "p256_OV_Is_pkc" "OV_Ip_pkc" "p256_OV_Ip_pkc" "OV_Is_pkc_skc" "p256_OV_Is_pkc_skc" "OV_Ip_pkc_skc" "p256_OV_Ip_pkc_skc" "snova2454" "p256_snova2454" "snova2454esk" "p256_snova2454esk" "snova37172" "p256_snova37172" "snova2455" "p384_snova2455" "snova2965" "p521_snova2965" "mqom2cat1gf16fastr5" "p256_mqom2cat1gf16fastr5" "mqom2cat3gf16fastr5" "p384_mqom2cat3gf16fastr5" "mqom2cat5gf16fastr5" "p521_mqom2cat5gf16fastr5")

# --- HELPER ROUTINES ---
compute_checksums() {
    local target_file="$1"
    local output_dir="$2"
    local alg="$3"
    local filename=$(basename "$target_file")
    local ext=$(echo "$alg" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')

    if [[ "$alg" == *"SHAKE"* ]]; then
        openssl dgst "${PROVIDER_ARGS[@]}" -"$alg" -xoflen 64 -out "${output_dir}/${filename}.${ext}" "$target_file" 2>/dev/null || true
    else
        openssl dgst "${PROVIDER_ARGS[@]}" -"$alg" -out "${output_dir}/${filename}.${ext}" "$target_file" 2>/dev/null || true
    fi
}

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
            echo "[!] Invalid input. Please type a number between 1 and ${#list[@]}." >&2
        fi
    done
}

generate_key() {
    local algo=$1
    local out_file=$2

    if [ ${#CIPHER_ARGS[@]} -gt 0 ]; then
        openssl genpkey "${PROVIDER_ARGS[@]}" -algorithm "$algo" | \
        openssl pkey "${PROVIDER_ARGS[@]}" "${CIPHER_ARGS[@]}" "${PASS_OUT_ARGS[@]}" -out "$out_file"
    else
        openssl genpkey "${PROVIDER_ARGS[@]}" -algorithm "$algo" -out "$out_file"
    fi
}

# --- INTERACTIVE BUILD SEQUENCER ---
clear
echo "====================================================================="
echo "        PHASE 1: AUTHENTICATION CERTIFICATE AUTHORITY DESIGN"
echo "====================================================================="
echo "Select a Digital Signature family for your Root CA:"
for i in "${!SIG_FAMILIES[@]}"; do
    echo "$((i+1))) ${SIG_FAMILIES[$i]}"
done

while true; do
    read -p "Selection [1-${#SIG_FAMILIES[@]}]: " ca_fam_choice
    case "$ca_fam_choice" in
        1) CA_ALGO=$(select_variant LIST_MLDSA_STD); break ;;
        2) CA_ALGO=$(select_variant LIST_MLDSA_HYB); break ;;
        3) CA_ALGO=$(select_variant LIST_SLHDSA_SHA2); break ;;
        4) CA_ALGO=$(select_variant LIST_SLHDSA_SHAKE); break ;;
        5) CA_ALGO=$(select_variant LIST_FALCON); break ;;
        6) CA_ALGO=$(select_variant LIST_ALT_SIG); break ;;
        *) echo "[-] Invalid selection. Try again." ;;
    esac
done
echo "[+] Root CA Core Engine mapped to: $CA_ALGO"

echo -e "\n====================================================================="
echo "        PHASE 2: WEBSITE / END-ENTITY ALGORITHM SPECIFICATION"
echo "====================================================================="
echo "Select a Digital Signature family for your Website Certificate:"
for i in "${!SIG_FAMILIES[@]}"; do
    echo "$((i+1))) ${SIG_FAMILIES[$i]}"
done

while true; do
    read -p "Selection [1-${#SIG_FAMILIES[@]}]: " sig_fam_choice
    case "$sig_fam_choice" in
        1) SERVER_ALGO=$(select_variant LIST_MLDSA_STD); break ;;
        2) SERVER_ALGO=$(select_variant LIST_MLDSA_HYB); break ;;
        3) SERVER_ALGO=$(select_variant LIST_SLHDSA_SHA2); break ;;
        4) SERVER_ALGO=$(select_variant LIST_SLHDSA_SHAKE); break ;;
        5) SERVER_ALGO=$(select_variant LIST_FALCON); break ;;
        6) SERVER_ALGO=$(select_variant LIST_ALT_SIG); break ;;
        *) echo "[-] Invalid selection." ;;
    esac
done
echo "[+] Website End-Entity Key Engine mapped to: $SERVER_ALGO"

echo -e "\n====================================================================="
echo "        PHASE 3: SYMMETRIC PRIVKEY ENVELOPE SELECTION"
echo "====================================================================="
echo "1) ChaCha20 Stream Cipher"
echo "2) Advanced Encryption Standard (AES-256-CBC)"
echo "3) Camellia Block Cipher (CAMELLIA-256-CBC)"
echo "4) Unencrypted (Plaintext Key)"
while true; do
    read -p "Selection [1-4]: " cipher_choice
    if [[ "$cipher_choice" =~ ^[1-4]$ ]]; then break; else echo "[-] Invalid choice."; fi
done

CIPHER_ARGS=()
PASS_OUT_ARGS=()
PASS_IN_ARGS=()

case "$cipher_choice" in
    1) CIPHER_ARGS=("-chacha20") ;;
    2) CIPHER_ARGS=("-aes-256-cbc") ;;
    3) CIPHER_ARGS=("-camellia-256-cbc") ;;
    *) echo "[!] Generating keys unencrypted." ;;
esac

if [ ${#CIPHER_ARGS[@]} -gt 0 ]; then
    read -s -p "Enter a strong passphrase to encrypt your private keys: " pkey_pass
    echo ""
    PASS_OUT_ARGS=("-passout" "pass:$pkey_pass")
    PASS_IN_ARGS=("-passin" "pass:$pkey_pass")
fi

echo -e "\n====================================================================="
echo "        PHASE 4: FILE INTEGRITY HASH SELECTION"
echo "====================================================================="
echo "Select the cryptographic digest algorithm to hash your final keys and certs:"
CHOSEN_DIGEST=$(select_variant DIGESTS)
echo "[+] Integrity Engine mapped to: $CHOSEN_DIGEST"

SAFE_CA=$(echo "$CA_ALGO" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
SAFE_SRV=$(echo "$SERVER_ALGO" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')

TARGET_DIR="./pki_${SAFE_CA}_${SAFE_SRV}"
mkdir -p "$TARGET_DIR"

echo -e "\n====================================================================="
echo "        PHASE 5: EXECUTION AND COMPILATION"
echo "====================================================================="

echo "[*] Initializing CA Private Key (${CA_ALGO})..."
generate_key "$CA_ALGO" "${TARGET_DIR}/ca.key"

echo "[*] Engineering and Self-Signing Root CA Certificate..."
openssl req "${PROVIDER_ARGS[@]}" -x509 -new -key "${TARGET_DIR}/ca.key" "${PASS_IN_ARGS[@]}" -out "${TARGET_DIR}/ca.crt" -days 3650 -subj "/O=PQ Laboratory/CN=Quantum Safe CA"

echo "[*] Generating Server Private Key (${SERVER_ALGO})..."
generate_key "$SERVER_ALGO" "${TARGET_DIR}/server.key"

echo "[*] Extracting Cryptographic Public Key Component..."
openssl pkey "${PROVIDER_ARGS[@]}" -in "${TARGET_DIR}/server.key" "${PASS_IN_ARGS[@]}" -pubout -out "${TARGET_DIR}/server.pub"

echo "[*] Designing Standard Certificate Signing Request (CSR)..."
openssl req "${PROVIDER_ARGS[@]}" -new -key "${TARGET_DIR}/server.key" "${PASS_IN_ARGS[@]}" -out "${TARGET_DIR}/server.csr" -subj "/O=Secure Target Node/CN=secure.local"

echo "[*] Processing CSR through CA Signing Chain..."
openssl x509 "${PROVIDER_ARGS[@]}" -req -in "${TARGET_DIR}/server.csr" -CA "${TARGET_DIR}/ca.crt" -CAkey "${TARGET_DIR}/ca.key" "${PASS_IN_ARGS[@]}" -CAcreateserial -out "${TARGET_DIR}/server.crt" -days 365

rm -f "${TARGET_DIR}/server.csr"
rm -f "${TARGET_DIR}/ca.srl"

echo -e "\n====================================================================="
echo "        PHASE 6: FILE INTEGRITY HASH GENERATION"
echo "====================================================================="
echo "[*] Generating $CHOSEN_DIGEST checksum manifests..."

TARGET_FILES=("ca.key" "ca.crt" "server.key" "server.pub" "server.crt")
for target in "${TARGET_FILES[@]}"; do
    if [ -f "${TARGET_DIR}/${target}" ]; then
        echo "    -> Hashing: $target"
        compute_checksums "${TARGET_DIR}/${target}" "$TARGET_DIR" "$CHOSEN_DIGEST"
    fi
done

echo -e "\n====================================================================="
echo " [+] SUCCESSFUL ENGINE EXECUTION"
echo "====================================================================="
echo "Output Directory: $TARGET_DIR"
ls -la "$TARGET_DIR"
