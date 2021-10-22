{-# LANGUAGE PatternSynonyms #-}

module Test.Bcc.Chain.Block.Gen
  ( genBlockSignature,
    genHeaderHash,
    genHeader,
    genBody,
    genProof,
    genToSign,
    genBlock,
    genBlockWithEpochSlots,
    genBoundaryBlock,
    genBoundaryHeader,
    genABlockOrBoundaryHdr,
  )
where

import Bcc.Chain.Block
  ( ABlockOrBoundaryHdr (..),
    ABlockSignature (..),
    ABoundaryBlock (..),
    ABoundaryBody (..),
    ABoundaryHeader (..),
    AHeader,
    Block,
    BlockSignature,
    Body,
    Header,
    HeaderHash,
    Proof (..),
    ToSign (..),
    fromCBORABoundaryHeader,
    fromCBORAHeader,
    hashHeader,
    mkABoundaryHeader,
    mkBlockExplicit,
    mkHeaderExplicit,
    toCBORABoundaryHeader,
    toCBORHeader,
    pattern Body,
  )
import Bcc.Chain.Cole.API (reAnnotateUsing)
import Bcc.Chain.Delegation (signCertificate)
import Bcc.Chain.Genesis (GenesisHash (..))
import Bcc.Chain.Slotting
  ( EpochNumber (..),
    EpochSlots,
    WithEpochSlots (WithEpochSlots),
  )
import Bcc.Chain.Ssc (SscPayload (..), SscProof (..))
import Bcc.Crypto
  ( ProtocolMagicId,
    SignTag (SignBlock),
    noPassSafeSigner,
    safeToVerification,
    sign,
    toVerification,
  )
import Bcc.Prelude
import Data.Coerce (coerce)
import Hedgehog (Gen)
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Test.Bcc.Chain.Common.Gen
  ( genChainDifficulty,
  )
import qualified Test.Bcc.Chain.Delegation.Gen as Delegation
import Test.Bcc.Chain.Slotting.Gen
  ( genEpochAndSlotCount,
    genEpochNumber,
    genEpochSlots,
    genSlotNumber,
  )
import Test.Bcc.Chain.UTxO.Gen (genTxPayload, genTxProof)
import qualified Test.Bcc.Chain.Update.Gen as Update
import Test.Bcc.Crypto.Gen
  ( genAbstractHash,
    genSafeSigner,
    genSigningKey,
    genTextHash,
  )

genBlockSignature :: ProtocolMagicId -> EpochSlots -> Gen BlockSignature
genBlockSignature pm epochSlots =
  mkBlockSignature
    <$> genSafeSigner
    <*> genSigningKey
    <*> genEpochNumber
    <*> genToSign pm epochSlots
  where
    mkBlockSignature issuerSafeSigner delegateSK epoch toSign =
      let cert =
            signCertificate pm (toVerification delegateSK) epoch issuerSafeSigner
          issuerVK = safeToVerification issuerSafeSigner
          sig = sign pm (SignBlock issuerVK) delegateSK toSign
       in ABlockSignature cert sig

genHeaderHash :: Gen HeaderHash
genHeaderHash = coerce <$> genTextHash

genBody :: ProtocolMagicId -> Gen Body
genBody pm =
  Body
    <$> genTxPayload pm
    <*> pure SscPayload
    <*> Delegation.genPayload pm
    <*> Update.genPayload pm

genHeader :: ProtocolMagicId -> EpochSlots -> Gen Header
genHeader protocolMagicId epochSlots =
  mkHeaderExplicit'
    <$> genHeaderHash
    <*> genChainDifficulty
    <*> genSlotNumber
    <*> genBody protocolMagicId
    <*> Update.genProtocolVersion
    <*> Update.genSoftwareVersion
    <*> genSigningKey
  where
    mkHeaderExplicit'
      headerHash
      chainDifficulty
      slotNumber
      body
      protocolVersion
      softwareVersion
      signingKey =
        mkHeaderExplicit
          protocolMagicId
          headerHash
          chainDifficulty
          epochSlots
          slotNumber
          signingKey
          ( signCertificate
              protocolMagicId
              (toVerification signingKey)
              (EpochNumber 0)
              (noPassSafeSigner signingKey)
          )
          body
          protocolVersion
          softwareVersion

genProof :: ProtocolMagicId -> Gen Proof
genProof pm =
  Proof
    <$> genTxProof pm
    <*> pure SscProof
    <*> genAbstractHash (Delegation.genPayload pm)
    <*> Update.genProof pm

genToSign :: ProtocolMagicId -> EpochSlots -> Gen ToSign
genToSign pm epochSlots =
  ToSign
    <$> (mkAbstractHash <$> genHeader pm epochSlots)
    <*> genProof pm
    <*> genEpochAndSlotCount epochSlots
    <*> genChainDifficulty
    <*> Update.genProtocolVersion
    <*> Update.genSoftwareVersion
  where
    mkAbstractHash :: Header -> HeaderHash
    mkAbstractHash = hashHeader epochSlots

genBlockWithEpochSlots :: ProtocolMagicId -> Gen (WithEpochSlots Block)
genBlockWithEpochSlots pm = do
  epochSlots <- genEpochSlots
  WithEpochSlots epochSlots <$> genBlock pm epochSlots

genBlock :: ProtocolMagicId -> EpochSlots -> Gen Block
genBlock protocolMagicId epochSlots =
  mkBlockExplicit'
    <$> Update.genProtocolVersion
    <*> Update.genSoftwareVersion
    <*> genHeaderHash
    <*> genChainDifficulty
    <*> genSlotNumber
    <*> genBody protocolMagicId
    <*> genSigningKey
  where
    mkBlockExplicit'
      protocolVersion
      softwareVersion
      headerHash
      chainDifficulty
      slotNumber
      body
      signingKey =
        mkBlockExplicit
          protocolMagicId
          protocolVersion
          softwareVersion
          headerHash
          chainDifficulty
          epochSlots
          slotNumber
          signingKey
          ( signCertificate
              protocolMagicId
              (toVerification signingKey)
              (EpochNumber 0)
              (noPassSafeSigner signingKey)
          )
          body

genBoundaryBlock :: Gen (ABoundaryBlock ())
genBoundaryBlock =
  ABoundaryBlock
    <$> pure 0
    <*> genBoundaryHeader
    <*> pure (ABoundaryBody ())
    <*> pure ()

genBoundaryHeader :: Gen (ABoundaryHeader ())
genBoundaryHeader = do
  epoch <- Gen.word64 (Range.exponential 0 maxBound)
  mkABoundaryHeader
    <$> ( if epoch == 0
            then Left . GenesisHash . coerce <$> genTextHash
            else
              Gen.choice
                [ Right <$> genHeaderHash,
                  Left . GenesisHash . coerce <$> genTextHash
                ]
        )
    <*> pure epoch
    <*> genChainDifficulty
    <*> pure ()

genABlockOrBoundaryHdr ::
  ProtocolMagicId ->
  EpochSlots ->
  Gen (ABlockOrBoundaryHdr ByteString)
genABlockOrBoundaryHdr pm es =
  Gen.choice
    [ ABOBBlockHdr . reAnnotateHdr <$> genHeader pm es,
      ABOBBoundaryHdr . reAnnotateBoundaryHdr <$> genBoundaryHeader
    ]
  where
    reAnnotateHdr :: AHeader () -> AHeader ByteString
    reAnnotateHdr =
      reAnnotateUsing
        (toCBORHeader es)
        (fromCBORAHeader es)

    reAnnotateBoundaryHdr :: ABoundaryHeader () -> ABoundaryHeader ByteString
    reAnnotateBoundaryHdr =
      reAnnotateUsing
        (toCBORABoundaryHeader pm)
        fromCBORABoundaryHeader
