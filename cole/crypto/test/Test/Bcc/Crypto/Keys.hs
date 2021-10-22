{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Test.Bcc.Crypto.Keys
  ( tests,
  )
where

import Bcc.Crypto.Signing
  ( deterministicKeyGen,
    fullVerificationKeyF,
    parseFullVerificationKey,
    redeemDeterministicKeyGen,
    redeemToVerification,
    safeDeterministicKeyGen,
    toVerification,
  )
import Bcc.Prelude
import Formatting (sformat)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Test.Bcc.Crypto.Gen (genPassPhrase, genVerificationKey)

--------------------------------------------------------------------------------
-- Main Test Action
--------------------------------------------------------------------------------

tests :: IO Bool
tests = checkParallel $$discover

--------------------------------------------------------------------------------
-- Key Properties
--------------------------------------------------------------------------------

-- | Derived 'VerificationKey' is the same as generated one
prop_pubKeyDerivedGenerated :: Property
prop_pubKeyDerivedGenerated = property $ do
  seed <- forAll $ Gen.bytes (Range.singleton 32)
  let (vk, sk) = deterministicKeyGen seed
  vk === toVerification sk

prop_pubKeyParsing :: Property
prop_pubKeyParsing = property $ do
  vk <- forAll genVerificationKey
  parseFullVerificationKey (sformat fullVerificationKeyF vk) === Right vk

-- | Derived 'RedeemVerificationKey' is the same as generated one
prop_redeemVerKeyDerivedGenerated :: Property
prop_redeemVerKeyDerivedGenerated = property $ do
  seed <- forAll $ Gen.bytes (Range.singleton 32)
  let (vk, sk) =
        fromMaybe (panic "redeem keygen failed") $ redeemDeterministicKeyGen seed
  vk === redeemToVerification sk

-- | Derived 'VerificationKey' is the same as generated one
prop_safeVerKeyDerivedGenerated :: Property
prop_safeVerKeyDerivedGenerated = property $ do
  pp <- forAll genPassPhrase
  seed <- forAll $ Gen.bytes (Range.singleton 32)
  let (vk, sk) = safeDeterministicKeyGen seed pp
  vk === toVerification sk
