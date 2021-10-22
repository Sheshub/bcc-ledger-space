module Test.Bcc.Chain.Elaboration.Keys
  ( elaborateKeyPair,
    elaborateVKey,
    elaborateVKeyGenesis,
    elaborateVKeyGenesisHash,

    -- * Abstract verification-key elaboration functions
    vKeyPair,
    vKeyToSKey,
    vKeyToSafeSigner,
  )
where

import Cole.Spec.Ledger.Core
  ( KeyPair,
    Owner (Owner),
    VKey (VKey),
    VKeyGenesis (VKeyGenesis),
    keyPair,
    owner,
    sKey,
  )
import Bcc.Chain.Common (KeyHash, hashKey)
import Bcc.Crypto.Signing (SafeSigner, SigningKey, VerificationKey, deterministicKeyGen, noPassSafeSigner)
import Bcc.Prelude
import qualified Data.ByteString as BS
import Data.ByteString.Builder (integerDec, toLazyByteString)
import qualified Data.ByteString.Lazy as BSL

elaborateKeyPair :: KeyPair -> (VerificationKey, SigningKey)
elaborateKeyPair kp = deterministicKeyGen $ padSeed seed
  where
    Owner o = owner $ sKey kp
    padSeed s =
      let padLength = max 0 (32 - BS.length s) in BS.replicate padLength 0 <> s
    seed = BSL.toStrict . toLazyByteString . integerDec $ fromIntegral o

vKeyPair :: VKey -> KeyPair
vKeyPair (VKey o) = keyPair o

elaborateVKey :: VKey -> VerificationKey
elaborateVKey = fst . elaborateKeyPair . vKeyPair

vKeyToSKey :: VKey -> SigningKey
vKeyToSKey = snd . elaborateKeyPair . vKeyPair

vKeyToSafeSigner :: VKey -> SafeSigner
vKeyToSafeSigner = noPassSafeSigner . vKeyToSKey

elaborateVKeyGenesis :: VKeyGenesis -> VerificationKey
elaborateVKeyGenesis (VKeyGenesis vk) = elaborateVKey vk

elaborateVKeyGenesisHash :: VKeyGenesis -> KeyHash
elaborateVKeyGenesisHash = hashKey . elaborateVKeyGenesis
