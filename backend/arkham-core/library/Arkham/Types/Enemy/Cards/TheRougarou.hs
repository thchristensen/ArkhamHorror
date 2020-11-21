{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Enemy.Cards.TheRougarou
  ( TheRougarou(..)
  , theRougarou
  )
where

import Arkham.Import

import Arkham.Types.Enemy.Attrs
import Arkham.Types.Enemy.Helpers
import Arkham.Types.Enemy.Runner

newtype TheRougarouMetadata = TheRougarouMetadata { damagePerPhase :: Int }
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

newtype TheRougarou = TheRougarou (Attrs `With` TheRougarouMetadata)
  deriving newtype (Show, ToJSON, FromJSON)

theRougarou :: EnemyId -> TheRougarou
theRougarou uuid =
  TheRougarou
    . (`with` TheRougarouMetadata 0)
    $ baseAttrs uuid "81028"
    $ (healthDamageL .~ 2)
    . (sanityDamageL .~ 2)
    . (fightL .~ 3)
    . (healthL .~ PerPlayer 5)
    . (evadeL .~ 3)
    . (uniqueL .~ True)

instance HasModifiersFor env TheRougarou where
  getModifiersFor = noModifiersFor

isEngage :: Message -> Bool
isEngage = \case
  EngageEnemy{} -> True
  _ -> False

instance ActionRunner env => HasActions env TheRougarou where
  getActions iid window (TheRougarou (attrs `With` _)) = do
    actions' <- getActions iid window attrs
    if any isEngage actions'
      then do
        playerCount <- getPlayerCount
        investigatorIds <- getInvestigatorIds
        let
          requiredClues = if playerCount > 2 then 2 else 1
          engageAction = Run
            [ SpendClues requiredClues investigatorIds
            , EngageEnemy iid (enemyId attrs) True
            ]
        canAfford <- (>= requiredClues)
          <$> getSpendableClueCount investigatorIds
        pure $ filter (not . isEngage) actions' <> [ engageAction | canAfford ]
      else pure actions'

instance EnemyRunner env => RunMessage env TheRougarou where
  runMessage msg (TheRougarou (attrs@Attrs {..} `With` metadata)) = case msg of
    EndPhase ->
      TheRougarou . (`with` TheRougarouMetadata 0) <$> runMessage msg attrs
    EnemyDamage eid _ _ n | eid == enemyId -> do
      let damage' = damagePerPhase metadata
      damageThreshold <- getPlayerCountValue (PerPlayer 1)
      if (damage' + n) > damageThreshold
        then do
          investigatorIds <- getInvestigatorIds
          leadInvestigatorId <- getLeadInvestigatorId
          farthestLocationIds <- case investigatorIds of
            [iid] -> map unFarthestLocationId <$> getSetList iid
            iids -> map unFarthestLocationId <$> getSetList iids
          case farthestLocationIds of
            [] -> error "can't happen"
            [x] -> unshiftMessage (MoveUntil x (EnemyTarget enemyId))
            xs -> unshiftMessage
              (chooseOne
                leadInvestigatorId
                [ MoveUntil x (EnemyTarget enemyId) | x <- xs ]
              )
          TheRougarou
            . (`with` TheRougarouMetadata ((damage' + n) `mod` damageThreshold))
            <$> runMessage msg attrs
        else
          TheRougarou
          . (`with` TheRougarouMetadata (damage' + n))
          <$> runMessage msg attrs
    _ -> TheRougarou . (`with` metadata) <$> runMessage msg attrs
