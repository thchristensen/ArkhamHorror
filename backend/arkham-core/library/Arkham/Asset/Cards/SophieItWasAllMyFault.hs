module Arkham.Asset.Cards.SophieItWasAllMyFault
  ( sophieItWasAllMyFault
  , SophieItWasAllMyFault(..)
  ) where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Runner
import Arkham.Card
import Arkham.Card.PlayerCard
import Arkham.Criteria
import Arkham.GameValue
import Arkham.Matcher
import Arkham.Target

newtype SophieItWasAllMyFault = SophieItWasAllMyFault AssetAttrs
  deriving anyclass IsAsset
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

sophieItWasAllMyFault :: AssetCard SophieItWasAllMyFault
sophieItWasAllMyFault = assetWith
  SophieItWasAllMyFault
  Cards.sophieItWasAllMyFault
  (canLeavePlayByNormalMeansL .~ False)

instance HasAbilities SophieItWasAllMyFault where
  getAbilities (SophieItWasAllMyFault x) =
    [ restrictedAbility
          x
          1
          (OwnsThis <> InvestigatorExists
            (You <> InvestigatorWithDamage (AtMost $ Static 4))
          )
        $ ForcedAbility AnyWindow
    ]

instance HasModifiersFor SophieItWasAllMyFault where
  getModifiersFor _ (InvestigatorTarget iid) (SophieItWasAllMyFault attrs)
    | controlledBy attrs iid = pure $ toModifiers attrs [AnySkillValue (-1)]
  getModifiersFor _ _ _ = pure []

instance RunMessage SophieItWasAllMyFault where
  runMessage msg a@(SophieItWasAllMyFault attrs) = case msg of
    UseCardAbility iid source _ 1 _ | isSource attrs source ->
      a <$ push (Flip iid (toSource attrs) (toTarget attrs))
    Flip _ _ target | isTarget attrs target -> do
      let
        sophieInLovingMemory = PlayerCard
          $ lookupPlayerCard Cards.sophieInLovingMemory (toCardId attrs)
        markId = fromJustNote "invalid" (assetController attrs)
      a <$ pushAll [ReplaceInvestigatorAsset markId sophieInLovingMemory]
    _ -> SophieItWasAllMyFault <$> runMessage msg attrs
