// dot8 example -- decrypt and verify (CKKS)
// Modeled on examples/mult/decrypt.cpp. Decrypts the result ciphertext
// and verifies against the real dot product of the two 8-element vectors.
//
// Usage: ./dot8_decrypt [key_dir]

#include "openfhe.h"
#include <cmath>

#include "ciphertext-ser.h"
#include "cryptocontext-ser.h"
#include "key/key-ser.h"
#include "scheme/ckksrns/ckksrns-ser.h"

using namespace lbcrypto;

int main(int argc, char* argv[]) {
    std::string keyDir = "dot8_keys";
    if (argc > 1) keyDir = argv[1];

    std::cout << "=== CKKS Dot8 -- Decrypt & Verify ===" << std::endl;
    std::cout << "Loading from: " << keyDir << std::endl;

    // ---- Load crypto context ----
    CryptoContext<DCRTPoly> cc;
    if (!Serial::DeserializeFromFile(keyDir + "/cc.bin", cc, SerType::BINARY))
        throw std::runtime_error("Failed to load crypto context");

    // ---- Load secret key ----
    PrivateKey<DCRTPoly> secretKey;
    if (!Serial::DeserializeFromFile(keyDir + "/sk.bin", secretKey, SerType::BINARY))
        throw std::runtime_error("Failed to load secret key");

    // ---- Load result ciphertext ----
    Ciphertext<DCRTPoly> ct_result;
    if (!Serial::DeserializeFromFile(keyDir + "/ct_result.bin", ct_result, SerType::BINARY))
        throw std::runtime_error("Failed to load result ciphertext");

    // ---- Load the two 8-element vectors for verification ----
    std::vector<double> va(8), vb(8);
    {
        std::ifstream valStream(keyDir + "/values.txt");
        if (!valStream.is_open())
            throw std::runtime_error("Failed to load values.txt");
        for (int i = 0; i < 8; i++) valStream >> va[i];
        for (int i = 0; i < 8; i++) valStream >> vb[i];
    }

    // ---- Decrypt ----
    Plaintext pt_result;
    cc->Decrypt(secretKey, ct_result, &pt_result);
    pt_result->SetLength(1);  // dot product result lives in slot 0

    double result = pt_result->GetRealPackedValue()[0];

    double expected = 0.0;
    for (int i = 0; i < 8; i++) expected += va[i] * vb[i];

    double tolerance = 0.01;
    double diff = std::abs(result - expected);

    std::cout << "Result: dot(a, b) = " << result
              << " (expected " << expected << ", diff " << diff << ")" << std::endl;

    if (diff < tolerance) {
        std::cout << "[PASS] " << result << " ~= " << expected << std::endl;
        return 0;
    } else {
        std::cerr << "[FAIL] " << result << " != " << expected
                  << " (diff " << diff << " > " << tolerance << ")" << std::endl;
        return 1;
    }
}
