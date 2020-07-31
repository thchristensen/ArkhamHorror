{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.SkillTest
  ( SkillTest(..)
  , DrawStrategy(..)
  , ResolveStrategy(..)
  , SkillTestResult(..)
  , initSkillTest
  )
where

import Arkham.Json
import Arkham.Types.Card
import Arkham.Types.Card.Id
import Arkham.Types.Classes
import Arkham.Types.InvestigatorId
import Arkham.Types.Message
import Arkham.Types.Modifier
import Arkham.Types.SkillTestResult
import Arkham.Types.SkillType
import Arkham.Types.Source
import Arkham.Types.Target
import Arkham.Types.Token
import ClassyPrelude
import qualified Data.HashMap.Strict as HashMap
import qualified Data.HashSet as HashSet
import Lens.Micro

data DrawStrategy
  = DrawOne
  | DrawX Int
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

data ResolveStrategy
  = ResolveAll
  | ResolveOne
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

data SkillTest = SkillTest
  { skillTestInvestigator    :: InvestigatorId
  , skillTestSkillType :: SkillType
  , skillTestDifficulty      :: Int
  , skillTestOnSuccess       :: [Message]
  , skillTestOnFailure       :: [Message]
  , skillTestDrawStrategy    :: DrawStrategy
  , skillTestResolveStrategy :: ResolveStrategy
  , skillTestSetAsideTokens  :: [Token]
  , skillTestResult :: SkillTestResult
  , skillTestModifiers :: [Modifier]
  , skillTestCommittedCards :: HashMap CardId (InvestigatorId, Card)
  , skillTestSource :: Source
  }
  deriving stock (Show, Generic)

instance ToJSON SkillTest where
  toJSON = genericToJSON $ aesonOptions $ Just "skillTest"
  toEncoding = genericToEncoding $ aesonOptions $ Just "skillTest"

instance FromJSON SkillTest where
  parseJSON = genericParseJSON $ aesonOptions $ Just "skillTest"

instance HasSet CommitedCardId InvestigatorId SkillTest where
  getSet iid =
    HashSet.map CommitedCardId
      . HashMap.keysSet
      . HashMap.filter ((== iid) . fst)
      . skillTestCommittedCards

initSkillTest
  :: InvestigatorId
  -> Source
  -> SkillType
  -> Int
  -> [Message]
  -> [Message]
  -> [Modifier]
  -> SkillTest
initSkillTest iid source skillType' difficulty' onSuccess' onFailure' modifiers'
  = SkillTest
    { skillTestInvestigator = iid
    , skillTestSkillType = skillType'
    , skillTestDifficulty = difficulty'
    , skillTestOnSuccess = onSuccess'
    , skillTestOnFailure = onFailure'
    , skillTestDrawStrategy = DrawOne
    , skillTestResolveStrategy = ResolveAll
    , skillTestSetAsideTokens = mempty
    , skillTestResult = Unrun
    , skillTestModifiers = modifiers'
    , skillTestCommittedCards = mempty
    , skillTestSource = source
    }

modifiers :: Lens' SkillTest [Modifier]
modifiers = lens skillTestModifiers $ \m x -> m { skillTestModifiers = x }

setAsideTokens :: Lens' SkillTest [Token]
setAsideTokens =
  lens skillTestSetAsideTokens $ \m x -> m { skillTestSetAsideTokens = x }

committedCards :: Lens' SkillTest (HashMap CardId (InvestigatorId, Card))
committedCards =
  lens skillTestCommittedCards $ \m x -> m { skillTestCommittedCards = x }

result :: Lens' SkillTest SkillTestResult
result = lens skillTestResult $ \m x -> m { skillTestResult = x }

onFailure :: Lens' SkillTest [Message]
onFailure = lens skillTestOnFailure $ \m x -> m { skillTestOnFailure = x }

onSuccess :: Lens' SkillTest [Message]
onSuccess = lens skillTestOnSuccess $ \m x -> m { skillTestOnSuccess = x }

skillIconCount :: SkillTest -> Int
skillIconCount SkillTest {..} = length . filter matches $ concatMap
  (iconsForCard . snd)
  (HashMap.elems skillTestCommittedCards)
 where
  iconsForCard (PlayerCard MkPlayerCard {..}) = pcSkills
  iconsForCard _ = []
  matches SkillWild = True
  matches s = s == skillTestSkillType


type SkillTestRunner env = (HasQueue env, HasCard InvestigatorId env)

instance (SkillTestRunner env) => RunMessage env SkillTest where
  runMessage msg s@SkillTest {..} = case msg of
    AddOnFailure m -> pure $ s & onFailure %~ (m :)
    AddOnSuccess m -> pure $ s & onSuccess %~ (m :)
    HorrorPerPointOfFailure iid -> case skillTestResult of
      FailedBy n ->
        s <$ unshiftMessage (InvestigatorDamage iid SkillTestSource 0 n)
      _ -> error "Should not be called when not failed"
    DamagePerPointOfFailure iid -> case skillTestResult of
      FailedBy n ->
        s <$ unshiftMessage (InvestigatorDamage iid SkillTestSource n 0)
      _ -> error "Should not be called when not failed"
    DrawToken token -> pure $ s & setAsideTokens %~ (token :)
    FailSkillTest -> do
      unshiftMessage SkillTestEnds
      unshiftMessages skillTestOnFailure
      pure $ s & result .~ FailedBy skillTestDifficulty
    StartSkillTest -> s <$ unshiftMessages
      (HashMap.foldMapWithKey
          (\k (i, _) -> [DiscardCard i k])
          skillTestCommittedCards
      <> [ InvestigatorStartSkillTest
             skillTestInvestigator
             skillTestSkillType
             skillTestModifiers
         ]
      )
    SkillTestCommitCard iid cardId -> do
      card <- asks (getCard iid cardId)
      pure $ s & committedCards %~ HashMap.insert cardId (iid, card)
    SkillTestUncommitCard _ cardId ->
      pure $ s & committedCards %~ HashMap.delete cardId
    AddModifier SkillTestTarget modifier ->
      pure $ s & modifiers %~ (modifier :)
    SkillTestEnds -> s <$ unshiftMessages
      [ RemoveAllModifiersOnTargetFrom
        (InvestigatorTarget skillTestInvestigator)
        SkillTestSource
      , ReturnTokens skillTestSetAsideTokens
      ]
    SkillTestResults -> do
      unshiftMessage (Ask $ ChooseOne [SkillTestApplyResults])
      for_ skillTestCommittedCards $ \(iid, card) -> case card of
        PlayerCard MkPlayerCard {..} -> when
          (pcCardType == SkillType)
          (unshiftMessage (RunSkill iid pcCardCode skillTestResult))
        _ -> pure ()
      pure s
    SkillTestApplyResults -> do
      unshiftMessage SkillTestEnds

      case skillTestResult of
        SucceededBy _ -> unshiftMessages skillTestOnSuccess
        FailedBy _ -> unshiftMessages skillTestOnFailure
        Unrun -> pure ()

      unshiftMessages $ map
        (AddModifier (InvestigatorTarget skillTestInvestigator)
        . replaceModifierSource SkillTestSource
        )
        skillTestModifiers

      pure s
    RunSkillTest modifiedSkillValue -> do
      let modifiedSkillValue' = modifiedSkillValue + skillIconCount s
      unshiftMessage SkillTestResults
      putStrLn
        . pack
        $ "Modified skill value: "
        <> show modifiedSkillValue'
        <> "\nDifficulty: "
        <> show skillTestDifficulty
      if modifiedSkillValue' >= skillTestDifficulty
        then pure $ s & result .~ SucceededBy
          (modifiedSkillValue' - skillTestDifficulty)
        else pure $ s & result .~ FailedBy
          (skillTestDifficulty - modifiedSkillValue')
    _ -> pure s
