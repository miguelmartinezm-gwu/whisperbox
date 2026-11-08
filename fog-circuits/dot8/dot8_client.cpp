// dot8 example -- client side (CKKS)
// Modeled on examples/mult/client.cpp. Encrypts two 8-element vectors
// (CKKS slot-packed) instead of two scalars, and generates rotation keys
// needed for the server's sum-all-slots reduction (log2(8)=3 rotations).
//
// Usage: ./dot8_client [output_dir [ring_dim]]

#include "openfhe.h"
#include <filesystem>

#include "ciphertext-ser.h"
#include "cryptocontext-ser.h"
#include "key/key-ser.h"
#include "scheme/ckksrns/ckksrns-ser.h"

using namespace lbcrypto;

int main(int argc, char* argv[]) {
    std::string outputDir = "dot8_keys";
    uint32_t ring_dim = 65536;  // Fog-required ring dimension

    if (argc > 1) outputDir = argv[1];
    if (argc > 2) ring_dim = static_cast<uint32_t>(std::stoul(argv[2]));

    std::cout << "=== CKKS Dot8 -- Client (Key Generation) ===" << std::endl;
    std::cout << "Output directory: " << outputDir << std::endl;

    std::filesystem::create_directories(outputDir);

    // Frozen whisperbox artifacts: x_fraud (vector a) dotted with
    // centroid (vector b). Real values from train_scorer.mojo's output.
    std::vector<double> va = {-2.31222654, 1.95199201, -1.60985073, 3.99790559,
                               -0.52218786, -1.42654532, -2.53738731, 1.39165725};
    std::vector<double> vb = {-0.39064416, 0.29665194, -0.57576276, 0.37182237,
                               -0.2579675, -0.11442238, -0.45587087, 0.04671374};

    // ---- CKKS parameters (same shape as mult, Fog-valid ring dim) ----
    CCParams<CryptoContextCKKSRNS> parameters;
    parameters.SetSecurityLevel(HEStd_NotSet);
    parameters.SetRingDim(ring_dim);
    parameters.SetMultiplicativeDepth(1);   // one EvalMult level; rotations are depth-free
    parameters.SetScalingModSize(42);
    parameters.SetFirstModSize(57);
    parameters.SetScalingTechnique(FLEXIBLEAUTO);

    CryptoContext<DCRTPoly> cc = GenCryptoContext(parameters);
    cc->Enable(PKE);
    cc->Enable(KEYSWITCH);
    cc->Enable(LEVELEDSHE);
    cc->Enable(ADVANCEDSHE);

    std::cout << "Ring dimension: " << cc->GetRingDimension() << std::endl;

    // ---- Key generation ----
    auto keyPair = cc->KeyGen();
    cc->EvalMultKeyGen(keyPair.secretKey);

    // Rotation keys for sum-all-slots reduction over 8 packed values:
    // rotate by 1, 2, 4 (log2(8) = 3 steps) covers the standard
    // rotate-and-add tree used to sum a power-of-two number of slots.
    cc->EvalRotateKeyGen(keyPair.secretKey, {1, 2, 4});

    // ---- Serialize crypto context + keys ----
    if (!Serial::SerializeToFile(outputDir + "/cc.bin", cc, SerType::BINARY))
        throw std::runtime_error("Failed to serialize crypto context");
    if (!Serial::SerializeToFile(outputDir + "/pk.bin", keyPair.publicKey, SerType::BINARY))
        throw std::runtime_error("Failed to serialize public key");
    if (!Serial::SerializeToFile(outputDir + "/sk.bin", keyPair.secretKey, SerType::BINARY))
        throw std::runtime_error("Failed to serialize secret key");

    std::ofstream mkStream(outputDir + "/mk.bin", std::ios::out | std::ios::binary);
    if (!mkStream.is_open() || !cc->SerializeEvalMultKey(mkStream, SerType::BINARY))
        throw std::runtime_error("Failed to serialize eval mult key");
    mkStream.close();

    std::ofstream rkStream(outputDir + "/rk.bin", std::ios::out | std::ios::binary);
    if (!rkStream.is_open() || !cc->SerializeEvalAutomorphismKey(rkStream, SerType::BINARY))
        throw std::runtime_error("Failed to serialize rotation keys");
    rkStream.close();

    // ---- Encrypt the two 8-element vectors (CKKS slot-packed) ----
    auto pt_a = cc->MakeCKKSPackedPlaintext(va);
    auto pt_b = cc->MakeCKKSPackedPlaintext(vb);

    auto ct_a = cc->Encrypt(keyPair.publicKey, pt_a);
    auto ct_b = cc->Encrypt(keyPair.publicKey, pt_b);

    if (!Serial::SerializeToFile(outputDir + "/ct_a.bin", ct_a, SerType::BINARY))
        throw std::runtime_error("Failed to serialize ciphertext a");
    if (!Serial::SerializeToFile(outputDir + "/ct_b.bin", ct_b, SerType::BINARY))
        throw std::runtime_error("Failed to serialize ciphertext b");

    // Save plaintext vectors for verification at decrypt time
    std::ofstream valStream(outputDir + "/values.txt");
    for (double v : va) valStream << v << " ";
    valStream << std::endl;
    for (double v : vb) valStream << v << " ";
    valStream << std::endl;
    valStream.close();

    std::cout << "\nClient complete. Files written to " << outputDir << "/" << std::endl;
    return 0;
}
