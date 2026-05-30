## 1. XOF: Extendable-Output Functions (SHAKE128 and SHAKE256)

Traditional hash functions like SHA-256 or SHA-512 are **fixed-output functions**. No matter how much data you feed them, they emit exactly 256 or 512 bits.

An **Extendable-Output Function (XOF)** is a structural evolution of a hash function. You can feed it an input, and then ask it to stream out an *infinite* number of pseudorandom bits. You dictate the exact output length down to the byte.

### SHAKE128 and SHAKE256 (FIPS 202)

When NIST standardized SHA-3 (based on the Keccak "sponge" construction), they included two XOFs: **SHAKE128** and **SHAKE256**.

* The numbers (128 and 256) do *not* mean the output size; they represent the **maximum security level** (in bits) against collision attacks.
* **How they work:** They absorb your data into a internal mathematical state ("the sponge"). You can then pump or "squeeze" that sponge repeatedly to extract as many bytes as your protocol requires.
* **Primary Use Case:** Mask Generation Functions (MGF1) in RSA-OAEP padding, generating arbitrary-length symmetric keys from a seed, or expanding short seeds into massive arrays of polynomial coefficients in post-quantum cryptography (like ML-KEM and ML-DSA).

---

## 2. BLAKE2X: BLAKE2XB and BLAKE2XS

Just as NIST built XOFs into SHA-3, the creators of the ultra-fast **BLAKE2** hash family realized they also needed variable-length outputs. Their answer was **BLAKE2X**.

* **BLAKE2XS:** Optimized for 32-bit platforms. It can produce an output stream from 1 byte up to $65,534$ bytes ($2^{16}-2$ bytes).
* **BLAKE2XB:** Optimized for 64-bit platforms. It can produce an output stream up to a staggering 4 gibibytes ($2^{32}-2$ bytes).

### How it works under the hood

Unlike SHAKE, which uses a sponge construction natively capable of squeezing out continuous data, BLAKE2 is based on a traditional block-based compression function (similar to ChaCha20).

To achieve an extendable output, BLAKE2X uses a **tree hashing** mode. It sets up a virtual root node using standard BLAKE2, and then spawns parallel child nodes. It takes the output of the root, modifies a frame parameter to include a counter/index, and hashes it repeatedly to generate a massive, mathematically tied sequence of pseudo-random blocks.

---

## 3. KangarooTwelve (K12)

**KangarooTwelve** is a direct development from the creators of Keccak (SHA-3). While SHA-3 is incredibly secure, it is notoriously slower than competing algorithms like BLAKE2 when executed in software on standard CPUs. KangarooTwelve was designed to address this speed deficiency.

KangarooTwelve is a hyper-fast XOF that achieves its speed through two massive optimizations:

1. **Reduced Rounds:** The core Keccak permutation normally runs for 24 internal mathematical rounds. KangarooTwelve slashes this down to just **12 rounds**, massively accelerating throughput while maintaining an exceptionally high security margin (128 bits).
2. **Tree Hashing for Parallelism:** For small inputs, it hashes linearly. But if a file exceeds 8,192 bytes, K12 automatically splits the message into 8KB chunks, hashes them simultaneously across multiple CPU threads, and merges the results into a final root node.

---

## 4. SIMD Keccak f1600 Permutation

This is not a standalone algorithm, but a highly specialized, low-level **software execution strategy** used to accelerate Keccak-based cryptography (SHA-3, SHAKE, KangarooTwelve, and post-quantum primitives).

* **Keccak-f[1600]:** The internal engine of SHA-3. It operates on a state matrix comprising a $5 \times 5$ grid of 64-bit words ($5 \times 5 \times 64 = 1600$ bits).
* **SIMD (Single Instruction, Multiple Data):** Modern CPUs possess wide vector registers (AVX2 is 256-bit; AVX-512 is 512-bit) capable of running math on multiple data points simultaneously with a single clock cycle.

A **SIMD Keccak f1600 Permutation** means the developer has rewritten the core Keccak matrix rotations to leverage these vector registers. For example, using AVX-512, a CPU can run **four Keccak-f[1600] permutations at the exact same time**.

In the context of your post-quantum work, this is highly relevant: when an algorithm like ML-KEM matrix-multiplies rows of polynomials, it needs to expand multiple public seeds using SHAKE simultaneously. A SIMD-optimized Keccak implementation speeds this pipeline up drastically.

---

## 5. LWC: Lightweight Cryptography (Ascon v1.2)

For years, standard internet cryptography assumed devices had powerful CPUs (servers, laptops, smartphones). However, the explosion of the Internet of Things (IoT)—smart medical implants, RFID tags, automotive sensors—introduced microscopic microcontrollers that cannot run heavy AES or SHA-3 operations without stalling or draining their batteries instantly.

To fix this, NIST ran a multi-year **Lightweight Cryptography (LWC)** competition, concluding in 2023. The undisputed winner was **Ascon**.

### Ascon v1.2

Ascon is a family of lightweight cryptographic primitives designed specifically to operate inside constrained hardware environments with low gate counts and minimal power usage.

* **AEAD (Authenticated Encryption with Associated Data):** Ascon doesn't just encrypt data; it simultaneously provides an authentication tag (like AES-GCM), guaranteeing that the encrypted data hasn't been intercepted or tampered with by an attacker.
* **The Sponge Structure:** Interestingly, Ascon uses a lightweight variant of the same sponge construction found in Keccak/SHA-3, but optimized for a much smaller 320-bit internal state matrix.
* **Side-Channel Resistance:** Ascon was built from the ground up to be easily hardened in hardware against "side-channel attacks" (where an attacker measures changes in power consumption or electromagnetic radiation from an IoT chip to extract the secret key).
