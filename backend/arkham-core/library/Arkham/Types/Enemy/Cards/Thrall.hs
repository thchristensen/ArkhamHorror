module Arkham.Types.Enemy.Cards.Thrall
  ( Thrall(..)
  , thrall
  )
where

import Arkham.Import

import Arkham.Types.Enemy.Attrs
import Arkham.Types.Enemy.Runner

newtype Thrall = Thrall Attrs
  deriving newtype (Show, ToJSON, FromJSON, Entity)

thrall :: EnemyId -> Thrall
thrall uuid =
  Thrall
    $ baseAttrs uuid "02086"
    $ (healthDamageL .~ 1)
    . (sanityDamageL .~ 1)
    . (fightL .~ 2)
    . (healthL .~ Static 2)
    . (evadeL .~ 2)

instance HasModifiersFor env Thrall where
  getModifiersFor = noModifiersFor

instance ActionRunner env => HasActions env Thrall where
  getActions i window (Thrall attrs) = getActions i window attrs

instance EnemyRunner env => RunMessage env Thrall where
  runMessage msg e@(Thrall attrs@Attrs {..}) = case msg of
    InvestigatorDrawEnemy iid _ eid | eid == enemyId -> do
      locations <- getSetList ()
        >>= traverse (traverseToSnd $ (unClueCount <$>) . getCount)
      case maxes locations of
        [] -> throwIO (InvalidState "No locations")
        xs -> e <$ spawnAtOneOf iid enemyId xs
    _ -> Thrall <$> runMessage msg attrs
