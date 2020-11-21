{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Investigator.Cards.ZoeySamaras where

import Arkham.Import

import Arkham.Types.Investigator.Attrs
import Arkham.Types.Investigator.Runner
import Arkham.Types.Stats
import Arkham.Types.Trait

newtype ZoeySamaras = ZoeySamaras Attrs
  deriving newtype (Show, ToJSON, FromJSON)

instance HasModifiersFor env ZoeySamaras where
  getModifiersFor source target (ZoeySamaras attrs) =
    getModifiersFor source target attrs

zoeySamaras :: ZoeySamaras
zoeySamaras = ZoeySamaras $ baseAttrs
  "02001"
  "Zoey Samaras"
  Guardian
  Stats
    { health = 9
    , sanity = 6
    , willpower = 4
    , intellect = 2
    , combat = 4
    , agility = 2
    }
  [Believer, Hunter]

instance ActionRunner env => HasActions env ZoeySamaras where
  getActions iid (AfterEnemyEngageInvestigator You eid) (ZoeySamaras Attrs {..})
    | iid == investigatorId = do
      let
        ability = mkAbility
          (InvestigatorSource investigatorId)
          1
          (ReactionAbility (AfterEnemyEngageInvestigator You eid))

      modifiers' <- getModifiersFor
        (InvestigatorSource investigatorId)
        (InvestigatorTarget investigatorId)
        ()
      usedAbilities <- map unUsedAbility <$> getList ()
      pure
        [ ActivateCardAbilityAction investigatorId ability
        | (investigatorId, ability)
          `notElem` usedAbilities
          && CannotGainResources
          `notElem` modifiers'
        ]

  getActions i window (ZoeySamaras attrs) = getActions i window attrs

instance HasTokenValue env ZoeySamaras where
  getTokenValue (ZoeySamaras attrs) iid ElderSign
    | iid == investigatorId attrs = pure
    $ TokenValue ElderSign (PositiveModifier 1)
  getTokenValue (ZoeySamaras attrs) iid token = getTokenValue attrs iid token

instance InvestigatorRunner env => RunMessage env ZoeySamaras where
  runMessage msg i@(ZoeySamaras attrs@Attrs {..}) = case msg of
    UseCardAbility _ (InvestigatorSource iid) _ 1 | iid == investigatorId ->
      i <$ unshiftMessage (TakeResources investigatorId 1 False)
    ResolveToken _drawnToken ElderSign iid | iid == investigatorId ->
      i <$ unshiftMessage
        (CreateSkillTestEffect
          (EffectModifiers [DamageDealt 1])
          (InvestigatorSource investigatorId)
          (InvestigatorTarget investigatorId)
        )
    _ -> ZoeySamaras <$> runMessage msg attrs
