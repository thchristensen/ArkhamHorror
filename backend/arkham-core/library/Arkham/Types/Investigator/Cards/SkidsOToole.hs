{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Investigator.Cards.SkidsOToole where

import Arkham.Types.Classes
import Arkham.Types.ClassSymbol
import Arkham.Types.Investigator.Attrs
import Arkham.Types.Investigator.Runner
import Arkham.Types.Message
import Arkham.Types.Stats
import Arkham.Types.Token
import Arkham.Types.Trait
import ClassyPrelude
import Data.Aeson

newtype SkidsOToole = SkidsOToole Attrs
  deriving newtype (Show, ToJSON, FromJSON)

skidsOToole :: SkidsOToole
skidsOToole = SkidsOToole $ baseAttrs
  "01003"
  "\"Skids\" O'Toole"
  Rogue
  Stats
    { health = 8
    , sanity = 6
    , willpower = 2
    , intellect = 3
    , combat = 3
    , agility = 4
    }
  [Criminal]

instance (InvestigatorRunner env) => RunMessage env SkidsOToole where
  runMessage msg i@(SkidsOToole attrs@Attrs {..}) = case msg of
    UseCardAbility _ _ (InvestigatorSource iid) 1 | iid == investigatorId ->
      resources <- unResourceCount <$> asks (getCount iid)
      when (resources >= 2) $ unshiftMessages
        [ SpendResources iid 2
        , AddAction iid (InvestigatorSource iid)
        ]
    ResolveToken ElderSign iid skillValue | iid == investigatorId ->
      runTest skillValue 2
      i <$ unshiftMessage (AddOnSuccess (TakeResources iid 2 false))
    _ -> SkidsOToole <$> runMessage msg attrs
