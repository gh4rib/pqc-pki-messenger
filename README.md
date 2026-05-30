# pqc-pki-messenger
A hobby project to implemennt PQS-CA/Cert generation and PQS Messenger using openssl 3.5+ and liboqs on Debian/13.5.

Information you need if you are not familiar with post-quantum world
- ML-DSA (Dilithium) is strictly a digital signature algorithm. It can only be used to sign and verify messages to guarantee authenticity and integrity. It cannot be used to encrypt or decrypt data. For post-quantum asymmetric encryption/decryption, you must use ML-KEM (Kyber).
- As of mid-2026, the CA/Browser Forum has not authorized public Certificate Authorities (like Let's Encrypt or ZeroSSL) to issue ML-DSA certificates, and root stores (like Windows, Apple, or Mozilla) do not trust them yet. The first publicly trusted PQ certificates aren't expected to be broadly recognized until 2027.

---

## Requirements
- OpenSSL 3.5+ (Debian/13.5 has this by default)
- `` apt install gcc build-essential expect xxd git ``
- Compile the Open-Quantum-Safe ``liboqs`` & ``oqs-provider`` to use them with openssl

## Compile liboqs & oqs-provider
- Compiling liboqs
```bash

git clone -b main https://github.com/open-quantum-safe/liboqs.git
cd liboqs
mkdir build && cd build

# Configure and build
cmake -GNinja -DBUILD_SHARED_LIBS=ON ..
ninja

# Generate the .deb package
ninja package

# Install the generated package (e.g., liboqs-0.15.0-Linux.deb)
sudo apt install -y ./*.deb

# Update the linker cache so the next build finds liboqs.so
sudo ldconfig

```

- Compiling oqs-provier
```bash

git clone -b main https://github.com/open-quantum-safe/oqs-provider.git
cd oqs-provider

# Configure and build
cmake -S . -B _build
cmake --build _build
cd _build

# Run tests to ensure it linked correctly to liboqs and OpenSSL
ctest --parallel 4 --rerun-failed --output-on-failure -V

# Generate the .deb package
make package

# Install the generated package
sudo apt install -y ./*.deb

```

- Add the following configuration to the ``/etc/ssl/openssl.cnf``
```bash
[openssl_init]
providers = provider_sect

[provider_sect]
default = default_sect
oqsprovider = oqsprovider_sect

[default_sect]
activate = 1

[oqsprovider_sect]
activate = 1
```

- Verify ``oqs-provider`` is loaded by running ``openssl list -providers``

---




## PQ-PKI
The post-quantum safe PKI written with bash (wrapper for OpenSSL & liboqs) using algorithms they provide along with a test engine that run a PQ Server and Client using openssl to initiate and test
the result of the script.
<strong> It is just an implementation of the whole process which is not tested thoroughly by me. I just tested one combination of the algorithms and tested them </strong>.


