{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Enemy.Cards.FleshEater where

import Arkham.Import

import Arkham.Types.Enemy.Attrs
import Arkham.Types.Enemy.Runner

newtype FleshEater = FleshEater Attrs
  deriving newtype (Show, ToJSON, FromJSON)

fleshEater :: EnemyId -> FleshEater
fleshEater uuid =
  FleshEater
    $ baseAttrs uuid "01118"
    $ (healthDamageL .~ 1)
    . (sanityDamageL .~ 2)
    . (fightL .~ 4)
    . (healthL .~ Static 4)
    . (evadeL .~ 1)

instance HasModifiersFor env FleshEater where
  getModifiersFor = noModifiersFor

instance ActionRunner env => HasActions env FleshEater where
  getActions i window (FleshEater attrs) = getActions i window attrs

instance (EnemyRunner env) => RunMessage env FleshEater where
  runMessage msg e@(FleshEater attrs@Attrs {..}) = case msg of
    InvestigatorDrawEnemy iid _ eid | eid == enemyId ->
      e <$ spawnAt (Just iid) enemyId "Attic"
    _ -> FleshEater <$> runMessage msg attrs
