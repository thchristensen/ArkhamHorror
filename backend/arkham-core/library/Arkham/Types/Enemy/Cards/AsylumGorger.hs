module Arkham.Types.Enemy.Cards.AsylumGorger
  ( asylumGorger
  , AsylumGorger(..)
  ) where

import Arkham.Prelude

import Arkham.Enemy.Cards qualified as Cards
import Arkham.Types.Classes
import Arkham.Types.Enemy.Attrs
import Arkham.Types.Modifier

newtype AsylumGorger = AsylumGorger EnemyAttrs
  deriving anyclass IsEnemy
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity, HasAbilities)

instance HasModifiersFor env AsylumGorger where
  getModifiersFor _ target (AsylumGorger a) | isTarget a target = do
    pure
      $ toModifiers a
      $ CannotMakeAttacksOfOpportunity
      : [ CannotAttack | enemyMovedFromHunterKeyword a ]
  getModifiersFor _ _ _ = pure []


asylumGorger :: EnemyCard AsylumGorger
asylumGorger = enemy AsylumGorger Cards.asylumGorger (4, Static 5, 4) (3, 3)

instance EnemyRunner env => RunMessage env AsylumGorger where
  runMessage msg (AsylumGorger attrs) = AsylumGorger <$> runMessage msg attrs
