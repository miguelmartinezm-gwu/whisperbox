// dot8 example -- server side (CKKS)
// Modeled on examples/mult/server.cpp. Computes an 8-element dot product
// instead of a scalar multiply: element-wise EvalMult (CKKS does this
// slot-by-slot automatically on packed ciphertexts), then a rotate-and-add
// tree (EvalRotate by 1, 2, 4) to sum all 8 product slots into slot 0.
//
// Usage: ./dot8_server [key_dir]

#include "ciphertext-fwd.h"
#include "lattice/hal/lat-backend.h"
#include "openfhe.h"
#include "niobium/compiler.h"

#include "ciphertext-ser.h"
#include "cryptocontext-ser.h"
#include "key/key-ser.h"
#include "scheme/ckksrns/ckksrns-ser.h"

using namespace lbcrypto;

int main(int argc, char* argv[]) {
    // ---- Niobium compiler setup ----
    niobium::compiler().init(argc, argv);
    niobium::compiler().set_program_info(
        "dot8_server", "1.0", "CKKS 8-D dot product -- FHETCH trace");
    niobium::compiler().set_build_info(__FILE__, __LINE__, __TIMESTAMP__);

    niobium::Compiler::CacheParameters params;
    params.push_back({"workload", "ckks_dot8"});
    niobium::compiler().cache_parameters(params);

    std::string keyDir = "dot8_keys";
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg.find("--") != 0) { keyDir = arg; break; }
    }

    std::cout << "=== CKKS Dot8 -- Server ===" << std::endl;
    std::cout << "Loading from: " << keyDir << std::endl;

    // ---- Load crypto context ----
    CryptoContext<DCRTPoly> cc;
    if (!Serial::DeserializeFromFile(keyDir + "/cc.bin", cc, SerType::BINARY))
        throw std::runtime_error("Failed to load crypto context");

    std::cout << "Ring dimension: " << cc->GetRingDimension() << std::endl;

    // ---- Load ciphertexts ----
    Ciphertext<DCRTPoly> ct_a, ct_b;
    if (!Serial::DeserializeFromFile(keyDir + "/ct_a.bin", ct_a, SerType::BINARY))
        throw std::runtime_error("Failed to load ciphertext a");
    if (!Serial::DeserializeFromFile(keyDir + "/ct_b.bin", ct_b, SerType::BINARY))
        throw std::runtime_error("Failed to load ciphertext b");

    // ---- Load keys (mult key AND rotation keys, unlike mult's example) ----
    {
        std::ifstream mkStream(keyDir + "/mk.bin", std::ios::in | std::ios::binary);
        if (mkStream.is_open()) {
            if (!cc->DeserializeEvalMultKey(mkStream, SerType::BINARY))
                throw std::runtime_error("Failed to load eval mult key");
            std::cout << "Loaded eval mult key" << std::endl;
        }
    }
    {
        std::ifstream rkStream(keyDir + "/rk.bin", std::ios::in | std::ios::binary);
        if (rkStream.is_open()) {
            if (!cc->DeserializeEvalAutomorphismKey(rkStream, SerType::BINARY))
                throw std::runtime_error("Failed to load rotation keys");
            std::cout << "Loaded eval automorphism (rotation) key" << std::endl;
        }
    }

    // ---- Capture crypto context and tag polys for simulator ----
    niobium::compiler().capture_crypto_context(cc);
    niobium::compiler().tag_input("ct_a", ct_a);
    niobium::compiler().tag_input("ct_b", ct_b);
    niobium::compiler().tag_keys(cc);

    Ciphertext<DCRTPoly> ct_openfhe;

    if (!niobium::compiler().is_cache_valid()) {
        // ---- RECORDING PHASE ----
        const bool hollow = niobium::compiler().is_hollow_mode();
        std::cout << "\n--- Recording Dot8 (" << (hollow ? "hollow" : "real")
                  << " mode) ---" << std::endl;
        niobium::compiler().enable_hollow_mode(hollow);
        niobium::compiler().start();

        // Element-wise multiply: slot i = a[i] * b[i]
        auto ct_prod = cc->EvalMult(ct_a, ct_b);

        // Rotate-and-add tree: sum all 8 slots into slot 0.
        // After this: ct_sum's slot 0 = a[0]*b[0] + a[1]*b[1] + ... + a[7]*b[7]
        auto ct_sum = ct_prod;
        ct_sum = cc->EvalAdd(ct_sum, cc->EvalRotate(ct_sum, 1));
        ct_sum = cc->EvalAdd(ct_sum, cc->EvalRotate(ct_sum, 2));
        ct_sum = cc->EvalAdd(ct_sum, cc->EvalRotate(ct_sum, 4));

        auto ct_result = cc->Compress(ct_sum, 1);

        niobium::compiler().probe("result", ct_result);
        niobium::compiler().stop();
        niobium::compiler().enable_hollow_mode(false);

        if (!hollow)
            ct_openfhe = ct_result;
    }

    // ---- REPLAY ----
    std::cout << "\n--- Replay ---" << std::endl;
    if (!niobium::compiler().replay()) {
        std::cerr << "[ERROR] Replay failed" << std::endl;
        return 1;
    }

    // ---- Retrieve result ----
    Ciphertext<DCRTPoly> ct_result;
    if (niobium::compiler().result(cc, "result", ct_result)) {
        if (!Serial::SerializeToFile(keyDir + "/ct_result.bin", ct_result, SerType::BINARY)) {
            std::cerr << "Error: Failed to serialize result ciphertext" << std::endl;
            return 1;
        }
        std::cout << "Result ciphertext written to " << keyDir << "/ct_result.bin" << std::endl;

        if (ct_openfhe) {
            if (!Serial::SerializeToFile(keyDir + "/ct_result_openfhe.bin", ct_openfhe, SerType::BINARY)) {
                std::cerr << "Error: Failed to serialize OpenFHE reference ciphertext" << std::endl;
                return 1;
            }
            std::cout << "OpenFHE reference ciphertext written to " << keyDir << "/ct_result_openfhe.bin" << std::endl;
        }
    } else {
        std::cerr << "[ERROR] Could not retrieve result" << std::endl;
        return 1;
    }

    return 0;
}
